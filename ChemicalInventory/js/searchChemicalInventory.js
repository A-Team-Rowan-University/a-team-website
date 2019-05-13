function searchChemicals()
{
  var xhttp = new XMLHttpRequest

  //Grab input values + Define search type
  var purchaser_idInput = document.getElementById("purchaser_id").value;
  var custodian_idInput = document.getElementById("custodian_id").value;
  var chemical_idInput = document.getElementById("chemical_id").value;
  var storage_locationInput = document.getElementById("storage_location").value;
  var manualInput = document.getElementById("amount").value;

  //Determine what values are searched + Check Search Type
  var purchaser_idSearch = true;
  var custodian_idSearch = true;
  var chemical_idSearch = true;
  var storage_locationSearch = true;
  var manualSearch = true;

  if(purchaser_idInput === "") {
    purchaser_idSearch = false;
  }
  if(custodian_idInput === "") {
    custodian_idSearch = false;
  }
  if(chemical_idInput === "") {
    chemical_idSearch = false;
  }
  if(storage_locationInput === "") {
    storage_locationSearch = false;
  }
  if(manualInput === "") {
    manualSearch = false;
  }
  // Response Parsing on state change
  xhttp.onreadystatechange = function() {
    if (this.readyState == 4 && this.status == 200) {
      // Clear old table in case of update/multiple requests
      var oldData = document.getElementById("rtrndata");
      oldData.parentNode.removeChild(oldData);

      // Parse JSON object into variable
      var responseObject = JSON.parse(this.responseText);

      // Generate Table
      var usrRtrn = document.getElementById("userReturn");
      var tbl = document.createElement("table");
      tbl.setAttribute("id", "rtrndata");

      // Table Headers
      var thd = document.createElement("thead");
      for (var i = 0; i < 6; i++) {
        var th = document.createElement("th");
        switch (i) {
          case 0:
            th.innerHTML = "Chemical Inventory ID";
            break;
          case 1:
            th.innerHTML = "Purchaser ID";
            break;
          case 2:
            th.innerHTML = "Custodian ID";
            break;
          case 3:
            th.innerHTML = "Chemical ID";
            break;
          case 4:
            th.innerHTML = "Storage Location";
            break;
          case 5:
            th.innerHTML = "Amount";
            break;
        }
        thd.appendChild(th);
      }
      tbl.appendChild(thd);

      // Table Body
      var tbod = document.createElement("tbody")
      for (var i = 0; i < responseObject.entries.length; i++) {
        var trow = document.createElement("tr");
        for (var j = 0; j < 6; j++) {
          var td = document.createElement("td");
          switch (j) {
            case 0:
              td.innerHTML = responseObject.entries[i].id;
              break;
            case 1:
              td.innerHTML = responseObject.entries[i].purchaser_id;
              break;
            case 2:
              td.innerHTML = responseObject.entries[i].custodian_id;
              break;
            case 3:
              td.innerHTML = responseObject.entries[i].chemical_id;
              break;
            case 4:
              td.innerHTML = responseObject.entries[i].storage_location;
              break;
            case 5:
              td.innerHTML = responseObject.entries[i].amount;
              break;
          }
          trow.appendChild(td);
        }
        tbod.appendChild(trow);
      }
      tbl.appendChild(tbod);
      usrRtrn.appendChild(tbl);
    }
  };

  // Send Get Request
  if(purchaser_idSearch || custodian_idSearch || chemical_idSearch || storage_locationSearch || manualSearch)
  {
    var searchString = "/?";
    if(purchaser_idSearch) {
      searchString += ("purchaser_id=partial," + purchaser_idInput);
    }
    if(custodian_idSearch) {
      if(searchString.indexOf("?") === searchString.length - 1) {
        searchString += ("custodian_id=partial," + custodian_idInput);
      } else {
        searchString += ("&custodian_id=partial," + custodian_idInput);
      }
    }
    if(chemical_idSearch) {
      if(searchString.indexOf("?") === searchString.length - 1) {
        searchString += ("chemical_id=partial," + chemical_idInput);
      } else {
        searchString += ("&chemical_id=partial," + chemical_idInput);
      }
    }
    if(storage_locationSearch) {
      if(searchString.indexOf("?") === searchString.length - 1) {
        searchString += ("storage_location=partial," + storage_locationInput);
      } else {
        searchString += ("&storage_location=partial," + storage_locationInput);
      }
    }
    if(manualSearch) {
      if(searchString.indexOf("?") === searchString.length - 1) {
        searchString += ("amount=partial," + manualInput);
      } else {
        searchString += ("&amount=partial," + manualInput);
      }
    }
    console.log(database + searchString);
    xhttp.open("GET", database + searchString, true);
    xhttp.send();
  }
}
