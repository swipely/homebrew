require 'tempfile'

# TODO make update cope if things are moved around
# NOTE can't move main Formula so main formula can't be trumped
#      rationale: would create so much merge hell for users!
#      do for homebrew 2?

# TODO stringent brew doctor checks for dupe libs and tools
# TODO make formula display very visible warnings if dupe libs or tools after install
# TODO or auto-keg-only?

HOMEBREW_LIBRARY = HOMEBREW_REPOSITORY/"Library"

module Homebrew extend self

  def tap
    if ARGV.empty?
      (HOMEBREW_LIBRARY/"Taps").children.each do |tap|
        puts tap.basename.sub('-', '/') if (tap/'.git').directory?
      end
    else
      install_tap(*tap_args)
    end
  end

  def install_tap user, repo
    raise "brew install git" unless system "/usr/bin/which -s git"

    tapd = HOMEBREW_LIBRARY/"Taps/#{user}-#{repo}"
    raise "Already tapped!" if tapd.directory?
    abort unless system "git clone https://github.com/#{user}/homebrew-#{repo} #{tapd}"

    files = []
    tapd.find_formula{ |file| files << Pathname.new("#{user}-#{repo}").join(file) }
    link_tap_formula(files)
  end

  def link_tap_formula formulae
    ignores = (HOMEBREW_LIBRARY/"Formula/.gitignore").read.split rescue []

    cd HOMEBREW_LIBRARY/"Formula" do
      formulae.each do |formula|
        # using the system ln is the only way to get relative symlinks
        system "ln -s ../Taps/#{formula} 2>/dev/null"
        if $?.success?
          ignores << formula.basename.to_s
        else
          opoo "#{formula.basename('.rb')} conflicts"
        end
      end
    end

    tf = Tempfile.new("brew-tap")
    tf.write(ignores.uniq.join("\n"))
    tf.close
    mv tf.path, "#{HOMEBREW_LIBRARY}/Formula/.gitignore"
  end

  private

  def tap_args
    ARGV.first =~ %r{^(\w+)/(homebrew-)?(\w+)$}
    raise "Invalid usage" unless $1 and $3
    [$1, $3]
  end

end
