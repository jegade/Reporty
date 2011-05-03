cat mootools-core-1.3.1-full-compat.js  > live_plain.js
cat mootools-more-1.3.1.1.js     >> live_plain.js
cat mootools.formalize.js        >> live_plain.js
cat datepicker.js                    >> live_plain.js
cat custom.js                    >> live_plain.js
java -jar ../../../extern/yuicompressor-2.4.6.jar live_plain.js > live.js
