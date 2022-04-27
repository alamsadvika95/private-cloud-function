const functions = require('@google-cloud/functions-framework');
const escapeHtml = require('escape-html');
const mysql = require('mysql2');
const redis = require('redis');

functions.http('helloHttp', (req, res) => {
  const pool = mysql.createPool({
    connectionLimit : 1,
    host : '10.186.192.3',
    port : 3306, 
    user : 'root',
    password : 'Datalabs123',
    database : 'testing'
  });

  switch (req.method) {
    case 'GET':
      pool.query('SELECT * FROM product', function ( error, results ) {
        console.log(error);
        console.log(results);
        res.status(200).send(results);
      });

      break;
    case 'POST':
      const name = escapeHtml(req.body.name);
      const description = escapeHtml(req.body.description);
      const image = escapeHtml(req.body.image);
      
      pool.query(`INSERT INTO product (name, description, image) VALUES ("${name}", "${description}", "${image}")`, function ( error, results ) {
        console.log(error);
        res.status(200).send(results);
      });
      break;
    default:
      res.status(405).send({error: 'Something blew up!'});
      break;
  }
});