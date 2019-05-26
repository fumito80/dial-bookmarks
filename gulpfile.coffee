{ src, dest, series } = require 'gulp'
coffee = require 'gulp-coffee'
uglify = require('gulp-uglify-es').default
concat = require 'gulp-concat'
tap    = require 'gulp-tap'
zipfld = require 'zip-folder'
del    = require 'del'
# rename = require 'gulp-rename'

uglifyOrThru = ->
  if process.argv.includes 'prd'
    uglify()
  else
    tap (file) -> console.log 'Skip uglify: ' + file.path

zip = (done) ->
  if process.argv.includes 'prd'
    manifest = JSON.parse require('fs').readFileSync('./dist/manifest.json')
    zipfld './dist', "./zipped/package.#{manifest.version}.zip", (err) ->
      done(err)
  else
    console.log 'Skip zipped'
    done()

cp = ->
  src 'src/**/*.*'
    .pipe dest 'dist'

cpLib = ->
  src([
    'lib/jquery.min.js'
    'lib/jquery-ui-1.10.3.custom.min.js'
    'lib/underscore-min.js'
  ]).pipe \
    dest 'dist/lib'

compile = (source, coffeeOp = {}) ->
  source
    .pipe coffee coffeeOp
    .pipe uglifyOrThru()
    .pipe dest 'dist'

compileOther = ->
  compile src [
    'coffee/*.coffee'
    '!coffee/functions.coffee'
    '!coffee/popup.coffee'
    '!coffee/background.coffee'
  ]

compilePopup = ->
  compile src([
    'coffee/functions.coffee'
    'coffee/popup.coffee'
  ]).pipe \
    concat 'popup.coffee'

compileBackground = ->
  compile src([
    'coffee/functions.coffee'
    'coffee/background.coffee'
  ]).pipe \
    concat 'background.coffee'

mergePopup2 = ->
  src([
    'lib/jquery.min.js'
    'lib/jquery-ui-1.10.3.custom.min.js'
    'lib/jquery.nicescroll.min.js'
    'lib/jquery.contextmenu.r2.js'
    'dist/popup2.js'
  ]).pipe \
    concat 'popup2.js'
  .pipe dest 'dist'

clean = (cb) -> del ['dist'], cb

build = series(
  clean
  compileOther
  compileBackground
  compilePopup
  mergePopup2
  cp
  cpLib
  zip
)

exports.src = cp

exports.coffee = series(
  compileOther
  compileBackground
  compilePopup
  mergePopup2
)

exports.default = exports.prd = build
