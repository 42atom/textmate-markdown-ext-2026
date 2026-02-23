#!/System/Library/Frameworks/Ruby.framework/Versions/Current/usr/bin/ruby

# This script is run from `TM_MARKDOWN_POST_FILTER`: It receives the already
# rendered markdown document via $stdin and is expected to output a filtered
# version to $stdout. In our case we append scripts for MathJax and Mermaid.

puts $stdin.read
puts <<-SCRIPT
  <script type="text/x-mathjax-config">
    MathJax.Hub.Config({
      extensions: ["tex2jax.js"],
      jax: ["input/TeX", "output/HTML-CSS"],
      tex2jax: {
        inlineMath: [ ["$","$"], ["\\\\(","\\\\)"] ],
        displayMath: [ ["$$","$$"], ["\\\\[","\\\\]"] ],
        processEscapes: false
      },
      "HTML-CSS": { availableFonts: ["TeX"] }
    });
  </script>
  <script type="text/javascript" src="https://cdn.mathjax.org/mathjax/latest/MathJax.js?config=TeX-AMS-MML_HTMLorMML"></script>
  <script type="text/javascript" src="https://cdn.jsdelivr.net/npm/mermaid@10/dist/mermaid.min.js"></script>
  <script type="text/javascript">
    (function() {
      if (typeof mermaid === "undefined") return;
      mermaid.initialize({
        startOnLoad: true,
        securityLevel: "loose"
      });
    })();
  </script>
SCRIPT
