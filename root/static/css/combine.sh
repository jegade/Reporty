cat 1140.css            >  live_plain.css
cat typeimg.css         >> live_plain.css
cat smallerscreen.css   >> live_plain.css
cat mobile.css          >> live_plain.css
cat layout.css          >> live_plain.css

java -jar ../../../extern/yuicompressor-2.4.6.jar  live_plain.css > live.css
