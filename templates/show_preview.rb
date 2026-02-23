#!/System/Library/Frameworks/Ruby.framework/Versions/Current/usr/bin/ruby
require "uri"
require "cgi"
require "#{ENV["TM_SUPPORT_PATH"]}/lib/tm/htmloutput"
require "#{ENV["TM_SUPPORT_PATH"]}/lib/tm/markdown"

# If the document starts with YAML front matter, the Front Matter bundle may
# strip it before rendering. Excluding it improves source->preview ratio mapping.
def effective_lines_for_ratio(source, line_number)
  lines = source.lines
  total = [lines.count, 1].max
  return [total, line_number] if lines.empty?
  return [total, line_number] unless lines.first.to_s.strip == "---"

  closing = nil
  max_scan = [lines.count - 1, 200].min
  (1..max_scan).each do |i|
    token = lines[i].to_s.strip
    if token == "---" || token == "..."
      closing = i
      break
    end
  end
  return [total, line_number] unless closing

  fm_count = closing + 1
  effective_total = [lines.count - fm_count, 1].max
  effective_line = line_number <= fm_count ? 1 : (line_number - fm_count)
  [effective_total, effective_line]
end

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

  raw_line = ENV["TM_LINE_NUMBER"].to_s
  line_number = raw_line =~ /^\d+$/ ? raw_line.to_i : nil

  cursor_ratio = nil
  if line_number && line_number > 0
    effective_total, effective_line = effective_lines_for_ratio(source, line_number)
    effective_line = 1 if effective_line < 1
    effective_line = effective_total if effective_line > effective_total
    cursor_ratio = if effective_total <= 1
                     0.0
                   else
                     (effective_line - 1).to_f / (effective_total - 1)
                   end
  end

  # TM_REFRESH is set on auto-refresh. In that path, preserving prior scroll is
  # less jumpy than forcing line-ratio reposition on every keystroke.
  preferred_ratio = ENV.key?("TM_REFRESH") ? nil : cursor_ratio
  preferred_ratio_js = preferred_ratio.nil? ? "null" : format("%.8f", preferred_ratio)

  key_source = ENV["TM_FILEPATH"] || ENV["TM_FILENAME"] || "untitled"
  storage_key = "tm_preview_scroll_ratio:#{key_source}"
  storage_key_js = storage_key.gsub("\\", "\\\\").gsub('"', '\\"')

  io << html
  io << %Q(\n<script>(function(){
    var preferredRatio = #{preferred_ratio_js};
    var storageKey = "#{storage_key_js}";

    function clamp(n) {
      if (n < 0) return 0;
      if (n > 1) return 1;
      return n;
    }

    function readSavedRatio() {
      try {
        var raw = localStorage.getItem(storageKey);
        if (raw === null) return null;
        var num = parseFloat(raw);
        if (!isFinite(num)) return null;
        return clamp(num);
      } catch (_) {
        return null;
      }
    }

    function writeSavedRatio(ratio) {
      try {
        localStorage.setItem(storageKey, String(clamp(ratio)));
      } catch (_) {
        // Ignore storage failures (e.g. disabled storage).
      }
    }

    function scrollElement(el, ratio) {
      if (!el) return false;
      var max = el.scrollHeight - el.clientHeight;
      if (max <= 0) return false;
      el.scrollTop = Math.round(max * ratio);
      return true;
    }

    function activeScroller() {
      var content = document.getElementById("tm_webpreview_content");
      if (content && (content.scrollHeight - content.clientHeight) > 2) return content;
      return document.scrollingElement || document.documentElement || document.body;
    }

    function ratioFromElement(el) {
      if (!el) return 0;
      var max = el.scrollHeight - el.clientHeight;
      if (max <= 0) return 0;
      var top = el.scrollTop;
      if ((el === document.body || el === document.documentElement) && typeof window.pageYOffset === "number") {
        top = window.pageYOffset;
      }
      return clamp(top / max);
    }

    function applyScroll() {
      var ratio = preferredRatio;
      if (ratio === null) ratio = readSavedRatio();
      if (ratio === null) ratio = 0;
      ratio = clamp(ratio);

      var moved = false;

      var content = document.getElementById("tm_webpreview_content");
      moved = scrollElement(content, ratio) || moved;

      var root = document.scrollingElement || document.documentElement || document.body;
      moved = scrollElement(root, ratio) || moved;

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

      writeSavedRatio(ratioFromElement(activeScroller()));
    }

    function bindScrollPersistence() {
      var onScroll = function() {
        writeSavedRatio(ratioFromElement(activeScroller()));
      };

      window.addEventListener("scroll", onScroll, { passive: true });
      var content = document.getElementById("tm_webpreview_content");
      if (content) content.addEventListener("scroll", onScroll, { passive: true });
    }

    if (document.readyState === "loading") {
      document.addEventListener("DOMContentLoaded", function(){ setTimeout(applyScroll, 0); });
    } else {
      setTimeout(applyScroll, 0);
    }

    // Re-apply after layout settles (styles/images/scripts).
    setTimeout(applyScroll, 120);
    setTimeout(applyScroll, 280);
    setTimeout(applyScroll, 600);

    bindScrollPersistence();
  })();</script>)
end
