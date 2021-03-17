module.exports = {
  purge: [
    '../lib/**/*.ex',
    '../lib/**/*.leex',
    '../lib/**/*.eex',
    './js/**/*.js'
  ],
  darkMode: false, // or 'media' or 'class'
  theme: {
    fontFamily: {
      'mono': ['JetBrainsMono'],
    },
    extend: {},
  },
  variants: {
    extend: {},
  },
  plugins: [],
}
