const path = require('path');
const exphbs = require('express-handlebars');
var renderer = require('./render');
var io = require('./file.js');
var express = require('express');

const app = express();
const port = 3000;

// let content;
// content = JSON.parse(io.read_file('./data/xrefs.json'));
// app.use(express.static(__dirname + '/public'));
app.set('view engine', '.hbs');
app.set('views', path.join(__dirname,'views'));

app.engine('.hbs', exphbs({
  defaultLayout: 'cytoscape',
  extname: '.hbs',
  layoutsDir: path.join(__dirname, 'views/layouts/')
}));

// app.all('/'), function(req,res,next) {
//   res.header("Access-Control-Allow-Origin", "*");
//   res.header("Access-Control-Allow-Headers", "X-Requested-With");
//   next();
// }
app.use('/static',express.static(__dirname + '/static'));

app.get('/', function (request,response) {
  response.render('home', { name: 'Cytoscape Xref viewer', layout: 'cytoscape'})
});

app.get('/hybrid', function(request, response) {
  response.render('mixed', { layout: 'cytoscape' })
});

app.get('/sparqler', function(request, response) {
  response.render('sgvizler', {layout: 'sparqler'})
});

// app.get('/data', function (request,response) {
//   response.send(content)
// });

app.listen(port,(err) => {
  if (err) {
    return console.log('Error in server', err)
  }
});
