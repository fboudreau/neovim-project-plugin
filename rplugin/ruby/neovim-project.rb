require 'yaml'
require 'logger'
require 'pathname'
require 'neovim'

# Dependencies
# find linux utility
# Ranger & bclose
# ack and vim plugin Ack
# ctags
# git, gitk, git gui

Neovim.plugin do |plug|

    PROJECT_FILE_NAME='.vim_project'
    LOGFILE='/tmp/vim-project.log'

    proj = nil
    logger = Logger.new(LOGFILE)

    # Define some mappings when starting up
    # Essentially, the only map that is available is the one for opening a project.
    # After the project has been openned, other mappings will be made available. See
    # ProjectOpen.
    plug.autocmd(:VimEnter) do |nvim|
      nvim.command("map <leader>ap :ProjectOpen<CR>")
      nvim.command("autocmd BufReadPost,FileReadPost * :ProjectAddPath")
      #nvim.command("autocmd BufDelete * :ProjectRemovePath")
      nvim.command("autocmd VimLeave * :ProjectSaveSession")
      #nvim.command("autocmd VimEnter * :ProjectRestoreSession")
    end

    plug.command(:ProjectNew, :nargs => '*', :complete => :file) do |nvim, name, path|

        # Defaults if user does not specify these.
        name = 'no_name' if name.nil?
        path = './' if path.nil?

        if File.exists?(path)
            if not File.exist?(path + File::SEPARATOR + PROJECT_FILE_NAME)

                # populate with default information.
                proj = {
                    "version" => "1.0.0",
                    "name" => name, 
                    "root" => nil,
                    "paths" => [], 
                    "open_browsers" => true,
                    "ack_options" => "--ignore-file=is:tags --ignore-file=ext:map --ignore-file=ext:d --ignore-file=ext:cmd"
                }

                begin
                    File.open(path + File::SEPARATOR + PROJECT_FILE_NAME, "a" ){|f|
                        f.write(proj.to_yaml)
                    }

                    nvim.command(":ProjectGenerateTags")
                    nvim.command(":ProjectOpen")

                rescue Exception => e
                    nvim.message("Unable to create project file: #{e.message}\n")
                    log.error(e.message + ": " + e.backtrace.inspect)
                end
            else
                nvim.message("Project already exists.\n")
            end
        else
            nvim.message("Directory #{path} does not exist. Please specify an existing directory\n")
        end
    end

    #Open an existing project
    plug.command(:ProjectOpen, :complete => :file, :nargs => '*') do |nvim, path|
       

        begin
            # If a path was not specified, look for a project file in the current directory
            # and upwards.
            if path.nil?
                path = find_project_file
            end

            # If we found a project file, use it.
            if not path.nil? and File.exists?(path + File::SEPARATOR + '.vim_project')

                # Load the project file
                proj = YAML.load(File.read(path + File::SEPARATOR + PROJECT_FILE_NAME))

                # Store the absolute path to the project. Doesn't need to be in the file since we can
                # figure it out based on it's location.
                proj["root"] = File.absolute_path(path)

                # Add some maps
                nvim.command("map <c-i> :ProjectShowExplorer<CR>")
                nvim.command("map <c-n> :Ranger<CR>")
                nvim.command("map <leader>aa :ProjectAck ")
                nvim.command("map <leader>af :ProjectAckFrom ")
                nvim.command("map <leader>at :ProjectGenerateTags<CR>")
                nvim.command("map <leader>ac :ProjectFind<CR>")

                # Git related
                nvim.command("map <leader>gk :silent !gitk --all &<CR>")
                nvim.command("map <leader>gg :silent !git gui &<CR>")
                nvim.command("set sessionoptions=buffers")

                # Automatically show the explorers?
                
                if proj["open_browsers"] == true
                    nvim.command(":ProjectRestoreSession")
                    nvim.command(":silent TlistClose")
                    nvim.command(":Tlist")
                end

                logger.info("global: #{nvim.get_var("project_file_name")}")
                logger.info("Project file loaded: " + proj.inspect)


                # Check if user oppened any files from the command line. If so
                # add them to the paths list
                #nvim.list_bufs.each{|buffer|
                #    nvim.command("ProjectAddPath")
                #}

                 
                #proj['paths'].each{|p|
                #    nvim.command(":badd " + p)
                #}

                logger.info("See proj: #{see_proj.call}")
                
            else
                nvim.message("Project file not found.\n")
            end
        rescue Exception => e
            logger.info("#{e.message}: #{e.backtrace}")
        end

    end

    plug.command(:ProjectBuild, :nargs => '*') do | nvim, args|
        if not proj.nil?
            nvim.command("make -C " + proj["root"] + " " + proj["make_options"] + " " + args)
        else
            nvim.message("Project not open. Please use :ProjectOpen.\n")
        end
    end

    plug.command(:ProjectSaveSession, :nargs => 0) do |nvim|

        if not proj.nil?
            nvim.command("mksession! #{proj["root"]}/.vim_project_session")
        else
            nvim.message("Project not open. Please use :ProjectOpen.\n")
        end

    end

    plug.command(:ProjectRestoreSession, :nargs => 0) do |nvim|

        if not proj.nil?
            nvim.command("source #{proj["root"]}/.vim_project_session") if File.exists?("#{proj["root"]}/.vim_project_session")
        else
            nvim.message("Project not open. Please use :ProjectOpen.\n")
        end

    end




    # This command will search files using Ack from the root of the project.
    plug.command(:ProjectAck, :nargs => 1) do |nvim, string|

        if not proj.nil?
            # Run Ack without jumping to the first entry..
            nvim.command("Ack! #{proj['ack_options']} #{string} #{proj["root"]}")
        else
            nvim.message("Project not open. Please use :ProjectOpen.\n")
        end

    end

    plug.command(:ProjectMessage, :nargs => 1) do |nvim, string|
         nvim.message(string + "\n")
    end


    # This comman will search files using Ack from the selected location in the NERDtree
    plug.command(:ProjectAckFrom, :nargs => '*') do |nvim, path, string|

        if not proj.nil?

            # if a file is selected, we will search from it's parent directory. Otherwise,
            # we will search from the selected directory
            if File.file?(path)
                @path = Pathname(path).parent.to_s
            else
                @path = Pathname(path).to_s
            end

            # Run Ack without jumping to the first entry. That's what the bang (!) is for. 
            nvim.command("Ack! #{proj['ack_options']} #{string}  #{@path}")
            
        else
            nvim.message("Project not open. Please use :ProjectOpen.\n")
        end
    end

    plug.command(:ProjectFind, :complete => :file, :nargs => '*') do |nvim, path|

        if not proj.nil?
            nvim.command("CommandT #{proj["root"]}")
        else
            nvim.message("Project not open. Please use :ProjectOpen.\n")
        end
    end

    plug.command(:ProjectFindFrom, :complete => :file, :nargs => '*') do |nvim, path|

        if not proj.nil?

            # if a file is selected, we will search from it's parent directory. Otherwise,
            # we will search from the selected directory
            if File.file?(path)
                @path = Pathname(path).parent.to_s
            else
                @path = Pathname(path).to_s
            end

            # Run Ack without jumping to the first entry. That's what the bang (!) is for. 
            nvim.command("CommandT #{@path}")

        else
            nvim.message("Project not open. Please use :ProjectOpen.\n")
        end


    end

    plug.command(:ProjectGenerateTags, :nargs => 0){|nvim|
        
        if not proj.nil?
            logger.info("Generating tags list")
            logger.info("Root path: #{proj["root"]}")
            system("find #{proj["root"]} -type f | ctags -f #{proj["root"]}/tags -L -")
        else
            nvim.message("Project not open. Please use :ProjectOpen.\n")
        end
    }



    plug.command(:ProjectRemovePath, :nargs => '?', :complete => :file){|nvim, path|

        if not proj.nil?

            if path.nil?
                path = File.absolute_path(nvim.get_current_buf.name)
            else
                path = File.absolute_path(path)
            end

            proj['paths'].delete(path)

            File.open(proj["root"] + File::SEPARATOR + PROJECT_FILE_NAME, "w" ){|f|
                f.write(proj.to_yaml)
            }

        else
            nvim.message("Project not open. Please use :ProjectOpen.\n")
        end


    }

    plug.command(:ProjectAddPath, :nargs => '?', :complete => :file){|nvim, path|


        logger.info("ProjectAddPath called")

        if not proj.nil?
            
            if path.nil?
                path = File.absolute_path(nvim.get_current_buf.name)
            else
                path = File.absolute_path(path)
            end

            proj['paths'] << path if not proj['paths'].include?(path)

            File.open(proj["root"] + File::SEPARATOR + PROJECT_FILE_NAME, "w" ){|f|
                f.write(proj.to_yaml)
            }

        else
            nvim.message("Project not open. Please use :ProjectOpen.\n")
        end


    }

    # List paths that are part of the project
    plug.command(:ProjectShowPaths, :nargs => 0) do |nvim|
        if not proj.nil?
            nvim.message("#{proj['paths']}\n")
        else
            nvim.message("Project not open. Please use :ProjectOpen.\n")
        end

    end

    # Define a command called "SetLine" which sets the contents of the current
    # line. This command is executed asynchronously, so the return value is
    # ignored.
    #plug.command(:ProjectAddDir, nargs: 1) do |nvim, str|
    #    nvim.current.line = str
    #end

    plug.command(:ProjectShowExplorer, nargs: 0) do |nvim|
        if not proj.nil?
            #nvim.command(":Ranger")
            nvim.command(":call OpenRangerIn(\"#{proj["root"]}\", \"edit\")")
        else
            nvim.message("Project not open. Please use :ProjectOpen.\n")
        end
    end


    plug.function(:ProjectGetRootPath, nargs: 0, sync: true) do |nvim|

        if not proj.nil?
            proj["root"]
        else
            nvim.message("Project not open. Please use :ProjectOpen.\n")
        end

    end

    plug.function(:ProjectAddPath, nargs: 0, sync: true) do |nvim|
        if not proj.nil?
            nvim.message(nvim.get_current_buf.name + "\n")
        else
            nvim.message("Project not open. Please use :ProjectOpen.\n")
        end

    end




    see_proj = lambda do
        proj["root"]
    end

    private

    def find_project_file

        p = Pathname(Dir.getwd())
        path = nil

        loop do

            if File.exists?(p.to_s + File::SEPARATOR + PROJECT_FILE_NAME)
                path = p.to_s
                break
            end

            p = p.parent

            break if ( p == Pathname('/') )

        end

        path

    end

    #ckfix.errp
end
