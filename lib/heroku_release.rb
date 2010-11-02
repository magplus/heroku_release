require 'ostruct'

module HerokuRelease
  @@config = OpenStruct.new(
    :heroku_remote => "heroku"
  )

  def self.config
    @@config
  end

  def self.config=(config)
    @@config = config
  end
  
  class Task
    def self.tasks
      {
        :push => nil,
        :tag => nil,
        :log => "Produces a changelog from release tags and their comments. Assumes tag comments have no newlines in them.",
        :current_release => "Show version of current release",
        :previous_release => "Show version of previous release",
        :pending => "Show git commits since last released version",
        :rollback => "Rollback to previous release and remove current release tag"
      }      
    end
    
    def push
      output 'Deploying site to Heroku ...'
      execute "git push #{config.heroku_remote} master"
    end

    def tag
      release_name = get_release_name
      commit_version_file(release_name) if config.version_file_path
      comment = ENV['COMMENT'] || 'Tagged release'
      output "Tagging release as '#{release_name}' with comment '#{comment}'"
      execute "git tag -a #{release_name} -m '#{comment}'"
      execute "git push --tags origin"
      execute "git push --tags #{config.heroku_remote}"
    end

    def log
      change_log = git_tags_with_comments.scan(/^\s*(release-\d+-\d+)\s*(.+)$/).reverse.map do |release, comment|
        "- #{release}\n\n#{comment}\n\n"
      end.join
      output "\n" + change_log
    end

    def current_release
      output current_release_version
    end

    def previous_release
      if previous_release_version
        output previous_release_version
      else
        output "no previous release found"
      end
    end

    def pending
      execute "git log #{current_release_version}..HEAD"
    end

    def rollback
      # Store releases in local variables so they don't change during tag deletion
      current = current_release_version
      previous = previous_release_version
      if previous
        output "Rolling back to '#{previous}' ..."
        execute "git push -f #{config.heroku_remote} #{previous}:master"
        output "Deleting rollbacked release '#{current}' ..."
        execute "git tag -d #{current}"
        execute "git push #{config.heroku_remote} :refs/tags/#{current}"
        execute "git push origin :refs/tags/#{current}"
        output 'Rollback completed'
      else
        output "No release tags found - cannot do rollback"
        output releases
      end
    end

    private

    def output(message)
      puts message
    end
    
    def execute(command)
      output `#{command}`.strip
    end

    def releases
      @releases ||= git_tags.split("\n").select { |t| t[0..7] == 'release-' }.sort
    end

    def current_release_version
      releases.last
    end

    def previous_release_version
      if releases.length >= 2 && previous = releases[-2]
        previous
      else
        nil
      end    
    end

    def commit_version_file(release_name)
      output "Committing version file for release #{release_name}"
      File.open(config.version_file_path, "w") { |f| f.print release_name }
      execute "git add #{config.version_file_path}"
      execute "git commit -m 'Updated version file to #{release_name}'"
      execute "git push origin master"
    end

    def get_release_name
      "release-#{Time.now.utc.strftime("%Y%m%d-%H%M%S")}"
    end

    def git_tags
      `git tag`
    end

    def git_tags_with_comments
      `git tag -n`
    end
    
    def config
      HerokuRelease.config
    end
  end
end