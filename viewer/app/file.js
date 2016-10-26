const fs = require('fs')

function read_file(path) {
  let content;
  try {
    content = fs.readFileSync(path,'utf-8');
  } catch (ex) {
    console.log(ex);
  }
  return content;
}

module.exports.read_file = read_file