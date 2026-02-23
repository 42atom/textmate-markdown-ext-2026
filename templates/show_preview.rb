#!/System/Library/Frameworks/Ruby.framework/Versions/Current/usr/bin/ruby
require "uri"
require "cgi"
require "#{ENV["TM_SUPPORT_PATH"]}/lib/tm/htmloutput"
require "#{ENV["TM_SUPPORT_PATH"]}/lib/tm/markdown"

TextMate::HTMLOutput.show(:title => "Markdown Preview", :sub_title => ENV["TM_FILENAME"]) do |io|
  if ENV['TM_PROJECT_DIRECTORY']
    # Respect project-level toolchain overrides (e.g. bundle exec redcarpet).
    Dir.chdir ENV['TM_PROJECT_DIRECTORY']
  end

  if ENV["TM_FILEPATH"] && File.exist?(ENV["TM_FILEPATH"])
    io << "<base href='file://#{URI::DEFAULT_PARSER.escape(ENV["TM_FILEPATH"])}'>\n"
  end

  source = $stdin.read
  html = TextMate::Markdown.to_html(source)

  total_lines = [source.lines.count, 1].max
  current_line = ENV["TM_LINE_NUMBER"].to_i
  current_line = 1 if current_line < 1
  current_line = total_lines if current_line > total_lines
  ratio = if total_lines <= 1
            0.0
          else
            (current_line - 1).to_f / (total_lines - 1)
          end

  io << html
  io << %Q(\n<script>(function(){
    var ratio = #{format('%.8f', ratio)};
    if (ratio < 0) ratio = 0;
    if (ratio > 1) ratio = 1;

    function scrollElement(el) {
      if (!el) return false;
      var max = el.scrollHeight - el.clientHeight;
      if (max <= 0) return false;
      el.scrollTop = Math.round(max * ratio);
      return true;
    }

    function applyScroll() {
      var moved = false;

      var content = document.getElementById("tm_webpreview_content");
      moved = scrollElement(content) || moved;

      var root = document.scrollingElement || document.documentElement || document.body;
      moved = scrollElement(root) || moved;

      var maxWindow = Math.max(
        (document.documentElement ? document.documentElement.scrollHeight : 0),
        (document.body ? document.body.scrollHeight : 0)
      ) - window.innerHeight;
      if (maxWindow > 0) {
        window.scrollTo(0, Math.round(maxWindow * ratio));
        moved = true;
      }

      if (!moved) {
        var anchor = document.getElementById("scroll_to_here");
        if (anchor) anchor.scrollIntoView({block:"start", inline:"nearest"});
      }
    }

    if (document.readyState === "loading") {
      document.addEventListener("DOMContentLoaded", function(){ setTimeout(applyScroll, 0); });
    } else {
      setTimeout(applyScroll, 0);
    }

    // Re-apply after layout settles (styles/images/scripts).
    setTimeout(applyScroll, 120);
    setTimeout(applyScroll, 300);
    setTimeout(applyScroll, 600);
  })();</script>)
end
