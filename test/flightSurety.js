
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

  it('(airline) Fund the first airline', async () => {
    
    // ARRANGE
    let firstAirline = accounts[1];
    let funds = new BigNumber(10).pow(18);

    let isAirlineexistingAirline = await config.flightSuretyData.isAirline(firstAirline);
    assert.equal(isAirlineexistingAirline, true, "firstAirline should be registered");

    // ACT
    try {        
        await config.flightSuretyApp.fundAirline(config.firstAirline, {from: config.firstAirline, value: funds});
    }
    catch(e) {

    }

    let result = await config.flightSuretyData.isPaid.call(config.firstAirline);

    // ASSERT
    assert.equal(result, true, "First airline should be funded");

  });


  

  it('(airline) cannot register an Airline using registerAirline() if it is not funded', async () => {
    
    // ARRANGE
    let newAirline = accounts[2];

    // ACT
    try {
        await config.flightSuretyApp.registerAirline(newAirline, "Airline 1", {from: config.firstAirline});
    }
    catch(e) {

    }
    let result0 = await config.flightSuretyData.isPaid(newAirline);
    assert.equal(result0, false, "Airline is not yet funded");
    
    let newAirline2 = accounts[3];
    let registerWithoutBeingFunded = true;
    try {
        let ret = await config.flightSuretyApp.registerAirline(newAirline2, "Airline 2", {from: newAirline});
    }
    catch(e) {
        registerWithoutBeingFunded = false;
    }
    
    assert.equal(registerWithoutBeingFunded, false, "Airline should not be able to register another airline if it hasn't provided funding");

    let result = await config.flightSuretyData.isAirline.call(newAirline2);

    // ASSERT
    assert.equal(result, false, "Airline should not be able to register another airline if it hasn't provided funding");

  });


  it('(airline) cannot register 2 times the same Airline using registerAirline()', async () => {
    
    // ARRANGE
    let newAirline = accounts[2];
    let result = true; 
    // ACT
    try {
        let state = await config.flightSuretyApp.registerAirline(newAirline, "Airline 1", {from: config.firstAirline});
    }
    catch(e) {
        result = false;
        //console.log(e.toString());
    }

    // ASSERT
    assert.equal(result, false, "Airline should not be able to register 2 times the same Airline ");

  });


  it('(airline) the first Airline is registered and funded', async () => {
    let state = await config.flightSuretyData.isPaid(config.firstAirline);
    //console.log(state);
    // ASSERT
    assert.equal(state, true, "Owner should be the first registered and funded airline");

  });

  it('(airline) the first Airline can register by itself only 3 more funded airlines', async () => {
    // 2ND AIRLINE
    let newAirline2 = accounts[3];
    let funds = new BigNumber(10).pow(18);
    let state2 = await config.flightSuretyApp.registerAirline.call(newAirline2, "2nd airline", {from: config.firstAirline});
    // ASSERT
    assert.equal(state2.success, true, "first Airline should be able to register 2nd airline");
    assert.equal(state2.totalPaidAirlines, 1, "total number of funded / paid airlines should be 1");

    await config.flightSuretyApp.fundAirline(newAirline2, {from: newAirline2, value: funds});
    let paid2 = await config.flightSuretyData.isPaid(newAirline2);
    // ASSERT
    assert.equal(paid2, true, "2nd airline should be funded airline");

    // 3RD AIRLINE
    let newAirline3 = accounts[4];
    let state3 = await config.flightSuretyApp.registerAirline.call(newAirline3, "3rd airline", {from: config.firstAirline});
    // ASSERT
    assert.equal(state3.success, true, "first Airline should be able to register 3rd airline");
    let totalPaidAirln = await config.flightSuretyData.getTotalPaidAirlines();
    assert.equal(totalPaidAirln, 2, "total number of funded / paid airlines should be 2");
    let multicallsCnt = state3.votes.toNumber();
    assert.equal(multicallsCnt, 0, "total number of multicalls should be 0");

    await config.flightSuretyApp.fundAirline(newAirline3, {from: newAirline3, value: funds});
    let paid3 = await config.flightSuretyData.isPaid(newAirline3);
    // ASSERT
    assert.equal(paid3, true, "3rd airline should be funded airline");

    // 4TH AIRLINE
    let newAirline4 = accounts[5];
    let state4 = await config.flightSuretyApp.registerAirline.call(newAirline4, "4th airline", {from: config.firstAirline});
    // ASSERT
    assert.equal(state4.success, true, "first Airline should be able to register 4th airline");
    totalPaidAirln = await config.flightSuretyData.getTotalPaidAirlines();
    assert.equal(totalPaidAirln, 3, "total number of funded / paid airlines should be 3");
    multicallsCnt = state4.votes.toNumber();
    assert.equal(multicallsCnt, 0, "total number of multicalls should be 0");

    await config.flightSuretyApp.fundAirline(newAirline4, {from: newAirline4, value: funds});
    let paid4 = await config.flightSuretyData.isPaid(newAirline4);
    // ASSERT
    assert.equal(paid4, true, "4th airline should be funded airline");

    // 5TH AIRLINE
    let newAirline5 = accounts[6];
    let state5 = await config.flightSuretyApp.registerAirline.call(newAirline5, "Dummy 1", {from: config.firstAirline});
    assert.equal(state5.success, false, "first Airline shouldn't be able to register 5th airline, require multiparty consensus");
    console.log("Votes: " + state5.votes.toNumber());
    console.log("Majority: " + state5.Majority.toNumber());
    console.log("TotalPaidAirlines: " + state5.totalPaidAirlines.toNumber());
    console.log("Exist: " + state5.exist.toNumber());        
    let ae = await config.flightSuretyData.getAirlineState(newAirline5);
    console.log("Airline State: " + ae.toString());        

    // ASSERT
    totalPaidAirln = await config.flightSuretyData.getTotalPaidAirlines();
    assert.equal(totalPaidAirln, 4, "total number of funded / paid airlines should be 4");
    multicallsCnt = state5.votes.toNumber();
    assert.equal(multicallsCnt, 1, "total number of multicalls should be 1");

    });

    it(`(multiparty) Duplicated votes not counted for consensus`, async function () {

        // 5TH AIRLINE
        let newAirline5 = accounts[6];
        let existingAirline = accounts[3];        
        let state5 = await config.flightSuretyApp.registerAirline(newAirline5, "Dummy 1", {from: config.firstAirline});

        state5 = await config.flightSuretyApp.registerAirline(newAirline5, "Dummy 1", {from: config.firstAirline});


        console.log("Votes: " + state5.votes.toNumber());
        console.log("Majority: " + state5.Majority.toNumber());
        console.log("TotalPaidAirlines: " + state5.totalPaidAirlines.toNumber());
        console.log("Exist: " + state5.exist.toNumber());        
        let ae = await config.flightSuretyData.getAirlineState(newAirline5);
        console.log("Airline State: " + ae.toString());        
        assert.equal(state5.success, false, "duplicated votes not allowed to register 5th airline, require multiparty consensus");
        // ASSERT
        totalPaidAirln = await config.flightSuretyData.getTotalPaidAirlines();
        assert.equal(totalPaidAirln, 4, "total number of funded / paid airlines should be 4");
        multicallsCnt = state5.votes.toNumber();
        assert.equal(multicallsCnt, 1, "total number of multicalls should be 1");

    });


    it(`(multiparty) Registration of fifth and subsequent airlines requires multi-party consensus of 50% of registered airlines`, async function () {

        // 5TH AIRLINE
        let newAirline5 = accounts[6];
        let existingAirline = accounts[3];        
        let state6 = await config.flightSuretyApp.registerAirline.call(newAirline5, "Dummy 1", {from: existingAirline});

        console.log("Votes: " + state6.votes.toNumber());
        console.log("Majority: " + state6.Majority.toNumber());
        console.log("TotalPaidAirlines: " + state6.totalPaidAirlines.toNumber());
        console.log("Exist: " + state6.exist.toNumber());        
        let ae = await config.flightSuretyData.getAirlineState(newAirline5);
        console.log("Airline State: " + ae.toString());        

        // ASSERT
        assert.equal(state6.success, true, "required multiparty consensus 50% for 5th airline is attained");
        let multicallsCnt2 = state6.votes.toNumber();
        assert.equal(multicallsCnt2, 2, "total number of multicalls should be 2");
        assert.equal(state6.Majority.toNumber(), 2, "majority should be 2");

    });

});