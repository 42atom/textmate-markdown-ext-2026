#!/System/Library/Frameworks/Ruby.framework/Versions/Current/usr/bin/ruby
# Usage: markdown-github.rb [<file>...]
# Convert one or more GitHub Flavored Markdown files to HTML and print to
# standard output. With no <file> or when <file> is "-", read GitHub Flavored
# Markdown source text from standard input.

if ARGV.include?("--help")
  File.read(__FILE__).split("\n").grep(/^# /).each do |line|
    puts line[2..-1]
  end
  exit 0
end

require "rubygems"
require "cgi"

begin
  require "redcarpet"
  require "pygments"
rescue LoadError
  puts <<-EOS
<p>Please install the Redcarpet and Pygments.rb RubyGems by running the following:</p>

<pre><code>/usr/bin/gem install --user redcarpet pygments.rb</code></pre>
EOS
  exit 0
end

class PygmentsSmartyHTML < Redcarpet::Render::HTML
  include Redcarpet::Render::SmartyPants

  def block_code(code, language)
    language = language.to_s.strip.split(/\s+/).first
    language = "text" if language.nil? || language.empty?
    if language.casecmp("mermaid").zero?
      return "<pre class='mermaid'>#{CGI.escapeHTML(code.to_s)}</pre>"
    end

    lexer = Pygments::Lexer.find_by_alias(language)
    lexer_alias = lexer ? lexer.aliases.first : "text"
    Pygments.highlight(code, :lexer => lexer_alias)
  rescue StandardError
    Pygments.highlight(code, :lexer => "text")
  end
end

def checkbox_html(checked)
  "<li><input type='checkbox' #{"checked" if checked} style='margin-right:0.5em;'/>"
end

def markdown(text)
  options = {
    :filter_html     => true,
    :safe_links_only => true,
    :with_toc_data   => true,
    :hard_wrap       => true,
  }

  renderer = PygmentsSmartyHTML.new(options)
  extensions = {
    :no_intra_emphasis   => true,
    :tables              => true,
    :fenced_code_blocks  => true,
    :autolink            => true,
    :strikethrough       => true,
    :space_after_headers => true,
  }

  html = Redcarpet::Markdown.new(renderer, extensions).render(text)
  html.gsub!("<li>[ ]", checkbox_html(false))
  html.gsub!("<li>[x]", checkbox_html(true))
  html
end

# 加载 Typora 官方 github.css，并做最小兼容转换以适配 TextMate 预览结构。
THEME_FILE_MAP = {
  "github" => "typora-github.css",
  "techo" => "typora-techo.css",
  "han" => "typora-han.css",
  "vue" => "typora-vue.css",
  "bluetex" => "typora-bluetex.css",
  "lixiaolai" => "typora-lixiaolai.css",
  "lxl" => "typora-lixiaolai.css"
}.freeze

def selected_theme_file
  key = ENV["TM_MARKDOWN_THEME"].to_s.strip.downcase
  key = "github" if key.empty?
  THEME_FILE_MAP.fetch(key, THEME_FILE_MAP["github"])
end

# 加载主题 CSS，并做最小兼容转换以适配 TextMate 预览结构。
def selected_theme_css
  css_path = File.expand_path("../css/#{selected_theme_file}", __dir__)
  return "" unless File.file?(css_path)

  css = File.read(css_path)
  # 部分主题通过 @import 引入字体文件，TextMate 预览目录下通常不存在这些资源。
  css = css.gsub(/@import[^\n]*\n/, "")
  # TextMate 预览不支持 Typora 的导出指令，直接剔除。
  css = css.gsub(/@include-when-export[^\n]*\n/, "")
  # 主题自带字体资源路径不在 TextMate 预览目录下，避免无效请求和噪音。
  css = css.gsub(/@font-face\s*\{[^}]*\}\s*/m, "")
  # Typora 的容器选择器映射到 TextMate 预览根节点。
  css = css.gsub(".typora-export", "body")
  css = css.gsub("#write", "body")
  css = css.gsub(".markdown-here-wrapper", "body")
  css = css.gsub(".markdown-body", "body")
  css
rescue StandardError
  ""
end

puts "<style>#{Pygments.css(:style => "colorful")}</style>"
theme_css = selected_theme_css
puts "<style>#{theme_css}</style>" unless theme_css.empty?
puts markdown(ARGF.read)
