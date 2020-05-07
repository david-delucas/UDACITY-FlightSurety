import FlightSuretyApp from '../../build/contracts/FlightSuretyApp.json';
import FlightSuretyData from '../../build/contracts/FlightSuretyData.json'; 
import Config from './config.json';
import Web3 from 'web3';
import express from 'express';


let config = Config['localhost'];
let web3 = new Web3(new Web3.providers.WebsocketProvider(config.url.replace('http', 'ws')));
web3.eth.defaultAccount = web3.eth.accounts[0];
let flightSuretyApp = new web3.eth.Contract(FlightSuretyApp.abi, config.appAddress);

let oracles = [];

(async () => {

  let accounts = await web3.eth.getAccounts();
  const _orcl_ini = 35;
  const _orcl_end = 50;

  // Register oracles
  for (var i = _orcl_ini; i < _orcl_end; i++) {
    await flightSuretyApp.methods.registerOracle().send({from: accounts[i], value: web3.utils.toWei("1", "ether"), gas: 9999999});
  }


  /*
  const ON_TIME = 10;
  let events = flightSuretyApp.events.allEvents();
  events.watch((error, result) => {
    if (result.event === 'OracleRequest') {
      console.log(`\n\nOracle Requested: index: ${result.args.index.toNumber()}, flight:  ${result.args.flight}, timestamp: ${result.args.timestamp.toNumber()}`);
    } else {
      console.log(`\n\nFlight Status Available: flight: ${result.args.flight}, timestamp: ${result.args.timestamp.toNumber()}, status: ${result.args.status.toNumber() == ON_TIME ? 'ON TIME' : 'DELAYED'}, verified: ${result.args.verified ? 'VERIFIED' : 'UNVERIFIED'}`);
    }
  });

  await flightSuretyApp.events.allEvents({ fromBlock: 'latest' })
  .on('data', console.log)
  .on('changed', console.log)
  .on('error', console.log);
*/

  // Watch contract events
  flightSuretyApp.events.OracleRequest({ fromBlock: 0 }, async function (error, event) {
    if (error) console.log(error)
    console.log(event.returnValues.index);
    var flightStatusLst = [0, 10, 20, 30, 40, 50];
    for (var i = _orcl_ini; i < _orcl_end; i++) {
      var oracleIndexes = await flightSuretyApp.methods.getMyIndexes().call({from: accounts[i]});
      for (var j = 0; j < 3; j++) {
        if (oracleIndexes[j] == event.returnValues.index) {
          var flightStatus = flightStatusLst[Math.floor(Math.random() * 6)];
          console.log("flight status " + flightStatus);
          console.log(await flightSuretyApp.methods.submitOracleResponse(
            oracleIndexes[j], 
            event.returnValues.airline, 
            event.returnValues.flight, 
            event.returnValues.timestamp, 
            flightStatus).send({from: accounts[i]}));
        }
      }
    }
  });

})();



const app = express();
app.get('/api', (req, res) => {
    res.send({
      message: 'An API for use with your Dapp!'
    })
})

export default app;


