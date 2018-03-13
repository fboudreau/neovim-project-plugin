require 'yaml'
require 'logger'
require 'pathname'
require 'neovim'

# Dependencies
# find
# NERDTree
# ack and vim plugin Ack
# ctags

Neovim.plugin do |plug|

    PROJECT_FILE_NAME='.vim_project'
    LOGFILE='/tmp/vim-project.log'

    @proj = nil
    @log = Logger.new(LOGFILE)


    @log.info(Neovim.methods)

    # Define some mappings when starting up
    plug.autocmd(:VimEnter) do |nvim|
      nvim.command("map <leader>ap :ProjectOpen<CR>")
    end


    plug.command(:ProjectNew, :nargs => '*', :complete => :file) do |nvim, name, path|

        if name.nil? or path.nil?
            message(nvim, "Both project name and path must be specified") 
        else

            if File.exists?(path)
                if not File.exist?(path + File::SEPARATOR + PROJECT_FILE_NAME)

                    # populate with default information.
                    @proj = {
                        "name" => name, 
                        "paths" => [], 
                        "open_browsers" => true,
                        "ack_options" => "--ignore-file=is:tags --ignore-file=ext:map --ignore-file=ext:d"
                    }

                    begin
                        File.open(path + File::SEPARATOR + PROJECT_FILE_NAME, "a" ){|f|
                            f.write(@proj.to_yaml)
                        }

                        nvim.command(":ProjectOpen")
                        nvim.command(":ProjectGenerateTags")

                    rescue Exception => e
                        message(nvim, "Unable to create project file: #{e.message}")
                        log.error(e.message + ": " + e.backtrace.inspect)
                    end
                else
                    message(nvim, "Project already exists.")
                end
            else
                message(nvim, "Directory #{path} does not exist. Please specify an existing directory")
            end
        end
    end

    plug.command(:ProjectAck, :nargs => 1) do |nvim, string|

        # Run Ack without jumping to the first entry..
        nvim.command("Ack! #{@proj['ack_options']} #{string} #{@proj[:root]}")

    end

    #Open an existing project
    plug.command(:ProjectOpen, :complete => :file, :nargs => '*') do |nvim, path|
       
        begin
            if path.nil?
                path = find_project_file
            end

            if not path.nil? and File.exists?(path + File::SEPARATOR + '.vim_project')

                # Load the project file
                @proj = YAML.load(File.read(path + File::SEPARATOR + PROJECT_FILE_NAME))

                # Store the absolute path to the project. Doesn't need to be in the file since we can
                # figure it out based on it's location.
                @proj[:root] = File.absolute_path(path)

                # Add some maps
                nvim.command(":map <c-n> :ProjectShowExplorer<CR>")
                nvim.command("map <leader>aa :ProjectAck ")
                nvim.command("map <leader>at :ProjectGenerateTags<CR>")

                # Automatically show the explorers?
                @log.info("Open browsers? : #{@proj["open_browsers"]}")
                if @proj["open_browsers"] == true
                    nvim.command(":ProjectShowExplorer")
                    nvim.command(":Tlist")
                end
                @log.info("Project file loaded: " + @proj.inspect)

            else
                message(nvim, "Project file not found.")
            end
        rescue Exception => e
            @log.info("#{e.message}: #{e.backtrace}")
        end

    end

    plug.command(:ProjectGenerateTags, :nargs => 0){|nvim|
        if not @proj.nil?
            @log.info("Generating tags list")
            @log.info("Root path: #{@proj[:root]}")
            system("find #{@proj[:root]} -type f | ctags -f #{@proj[:root]}/tags -L -")
        else
            message(nvim, "Project not open. Please use :ProjectOpen.")
        end
    }

    plug.command(:ProjectAddPath, :nargs => 1, :compilete => :file){|nvim, path|
        
    }

    # List paths that are part of the project
    plug.command(:ProjectShowPaths, :nargs => 0) do |nvim|
        if not @proj.nil?
            message(nvim, @proj['paths'])
        else
            message(nvim, "Project not open. Please use :ProjectOpen.")
        end

    end

    # Define a command called "SetLine" which sets the contents of the current
    # line. This command is executed asynchronously, so the return value is
    # ignored.
    #plug.command(:ProjectAddDir, nargs: 1) do |nvim, str|
    #    nvim.current.line = str
    #end

    plug.command(:ProjectShowExplorer, nargs: 0) do |nvim|
        if not @proj.nil?
            nvim.command(":NERDTree #{@proj[:root]}")
        else
            message(nvim, "Project not open. Please use :ProjectOpen.")
        end
    end


    plug.function(:ProjectGetRootPath, nargs: 0, sync: true) do |nvim|

        if not @proj.nil?
            @proj[:root]
        else
            message(nvim, "Project not open. Please use :ProjectOpen.")
        end

    end

    private

    def message(nvim, str)
        nvim.command(":echom '#{str}'")
    end

    def find_project_file

        p = Pathname(Dir.getwd())
        path = nil

        loop do

            @log.info(p.to_s)

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
