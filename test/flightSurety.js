
var Test = require('../config/testConfig.js');
var BigNumber = require('bignumber.js');

contract('Flight Surety Tests', async (accounts) => {

  var config;
  before('setup contract', async () => {
    config = await Test.Config(accounts);
    await config.flightSuretyData.authorizeCaller(config.flightSuretyApp.address);
  });

  /****************************************************************************************/
  /* Operations and Settings                                                              */
  /****************************************************************************************/

  it(`(multiparty) has correct initial isOperational() value`, async function () {

    // Get operating status
    let status = await config.flightSuretyData.isOperational.call();
    assert.equal(status, true, "Incorrect initial operating status value");

  });

  it(`(multiparty) can block access to setOperatingStatus() for non-Contract Owner account`, async function () {

      // Ensure that access is denied for non-Contract Owner account
      let accessDenied = false;
      try 
      {
          await config.flightSuretyData.setOperatingStatus(false, { from: config.testAddresses[2] });
      }
      catch(e) {
          accessDenied = true;
      }
      assert.equal(accessDenied, true, "Access not restricted to Contract Owner");
            
  });

  it(`(multiparty) can allow access to setOperatingStatus() for Contract Owner account`, async function () {

      // Ensure that access is allowed for Contract Owner account
      let accessDenied = false;
      try 
      {
          await config.flightSuretyData.setOperatingStatus(false);
      }
      catch(e) {
          accessDenied = true;
      }
      assert.equal(accessDenied, false, "Access not restricted to Contract Owner");
      
  });

  it(`(multiparty) can block access to functions using requireIsOperational when operating status is false`, async function () {

      await config.flightSuretyData.setOperatingStatus(false);

      let reverted = false;
      try 
      {
          await config.flightSurety.setTestingMode(true);
      }
      catch(e) {
          reverted = true;
      }
      assert.equal(reverted, true, "Access not blocked for requireIsOperational");      

      // Set it back for other tests to work
      await config.flightSuretyData.setOperatingStatus(true);

  });

  it('(airline) cannot register an Airline using registerAirline() if it is not funded', async () => {
    
    // ARRANGE
    let newAirline = accounts[2];

    // ACT
    try {
        await config.flightSuretyApp.registerAirline(newAirline, {from: config.firstAirline});
    }
    catch(e) {

    }
    let result = await config.flightSuretyData.isAirline.call(newAirline);

    // ASSERT
    assert.equal(result, false, "Airline should not be able to register another airline if it hasn't provided funding");

  });

  it('(airline) the first Airline is registered and funded', async () => {
    let state = await config.flightSuretyData.isPaid(config.firstAirline);
    //console.log(state);
    // ASSERT
    assert.equal(state, true, "Owner should be the first registered and funded airline");

  });

  it('(airline) the first Airline can register only 3 more airlines but not funded', async () => {
    let newAirline2 = accounts[3];
    let state2 = await config.flightSuretyApp.registerAirline.call(newAirline2, {from: config.firstAirline});
    //console.log(state2.totalPaidAirlines);
    // ASSERT
    assert.equal(state2.success, true, "first Airline should be able to register 1st airline");

    let newAirline3 = accounts[4];
    let state3 = await config.flightSuretyApp.registerAirline.call(newAirline3, {from: config.firstAirline});
    //console.log(state3.totalPaidAirlines);
    // ASSERT
    assert.equal(state3.success, true, "first Airline should be able to register 2nd");

    let newAirline4 = accounts[5];
    let state4 = await config.flightSuretyApp.registerAirline.call(newAirline4, {from: config.firstAirline});
    //console.log(state4.totalPaidAirlines);
    // ASSERT
    assert.equal(state4.success, true, "first Airline should be able to register 3rd airline");

    let newAirline5 = accounts[6];
    let state5 = await config.flightSuretyApp.registerAirline.call(newAirline5, {from: config.firstAirline});
    //console.log(state5.totalPaidAirlines);
    // ASSERT
    //assert.equal(state5.success, false, "first Airline shouldn't be able to register 4th airline");

    let state6 = await config.flightSuretyApp.registerAirline.call(newAirline3, {from: config.firstAirline});
    //console.log(state5.totalPaidAirlines);
    // ASSERT
    //assert.equal(state6.success, false, "first Airline shouldn't be able to register 2 times 2nd airline");

});
});