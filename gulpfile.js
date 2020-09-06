const { src, dest, series } = require('gulp');
const coffee = require('gulp-coffee');
const uglify = require('gulp-uglify-es').default
const concat = require('gulp-concat');
const tap = require('gulp-tap');
const zipfld = require('zip-folder');
const del = require('del');
const fs = require('fs');

const i18nLangs = ["ja", "en"];

function readFile(path, postFn = String) {
  return new Promise((resolve, reject) => {
    fs.readFile(path, (err, data) => {
      if (err) {
        reject(err);
        return;
      }
      try {
        resolve(postFn(data));
      } catch (e) {
        reject(e);
      }
    });
  });
}

function writeFile(path, data, enc = 'utf8') {
  return new Promise((resolve, reject) => {
    fs.writeFile(path, data, enc, (err) => {
      if (err) {
        reject(err);
      } else {
        resolve();
      }
    });
  });
}

function buildMessages() {
  return Promise.all(i18nLangs.map((lang) => {
    return Promise.all([
      readFile(`./i18n/${lang}/messages.json`, JSON.parse),
      readFile(`./i18n/${lang}/options.json`),
      readFile(`./i18n/${lang}/ctxMenu.html`),
    ])
    .then(([messages, options, htmlCtxMenu]) => {
      Object.assign(messages, {
        options: { message: options },
        htmlContextMenus: { message: htmlCtxMenu },
      });
      writeFile("./src/_locales/#{lang}/messages.json", JSON.stringify(messages, null, '\t'));
    });
  }));
}

function uglifyOrThru() {
  if (process.argv.includes('prd')) {
    return uglify();
  } else {
    return tap((file) => console.log('Skip uglify: ' + file.path));
  }
}

function zip(done) {
  if (process.argv.includes('prd')) {
    const manifest = JSON.parse(require('fs').readFileSync('./dist/manifest.json'));
    zipfld('./dist', `./zipped/package.${manifest.version}.zip`, (err) => {
      done(err);
    });
  } else {
    console.log('Skip zipped');
    done();
  }
}

function cp() {
  return src('src/**/*.*')
    .pipe(dest('dist'));
}

function cpLib() {
  return src([
    'lib/jquery.min.js',
    'lib/jquery-ui-1.10.3.custom.min.js',
    'lib/underscore-min.js',
  ]).pipe(dest('dist/lib'));
}

function compile(source, coffeeOp = {}) {
  return source
    .pipe(coffee(coffeeOp))
    .pipe(uglifyOrThru())
    .pipe(dest('dist'));
}

function compileOther() {
  return compile(src([
    'coffee/*.coffee',
    '!coffee/functions.coffee',
    '!coffee/popup.coffee',
    '!coffee/background.coffee',
  ]));
}

function compilePopup() {
  return compile(
    src([
      'coffee/functions.coffee',
      'coffee/popup.coffee',
    ])
    .pipe(concat('popup.coffee'))
  );
}

function compileBackground() {
  return compile(
    src([
      'coffee/functions.coffee',
      'coffee/background.coffee',
    ])
    .pipe(concat('background.coffee'))
  );
}

function mergePopup2() {
  return src([
    'lib/jquery.min.js',
    'lib/jquery-ui-1.10.3.custom.min.js',
    'lib/jquery.nicescroll.min.js',
    'lib/jquery.contextmenu.r2.js',
    'dist/popup2.js',
  ])
  .pipe(concat('popup2.js'))
  .pipe(dest('dist'));
}

function clean(cb) {
  return del(['dist'], cb);
}

const build = series(
  clean,
  compileOther,
  compileBackground,
  compilePopup,
  mergePopup2,
  cp,
  cpLib,
  zip,
);

exports.src = cp;

exports.coffee = series(
  compileOther,
  compileBackground,
  compilePopup,
  mergePopup2,
);

exports.default = exports.prd = build;
