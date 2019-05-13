function getUsers()
{
  var xhttp = new XMLHttpRequest

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
      for (var i = 0; i < 5; i++) {
        var th = document.createElement("th");
        switch (i) {
          case 0:
            th.innerHTML = "ID";
            break;
          case 1:
            th.innerHTML = "First Name";
            break;
          case 2:
            th.innerHTML = "Last Name";
            break;
          case 3:
            th.innerHTML = "Banner ID";
            break;
          case 4:
            th.innerHTML = "Email";
            break;
        }
        thd.appendChild(th);
      }
      tbl.appendChild(thd);

      // Table Body
      var tbod = document.createElement("tbody")
      for (var i = 0; i < responseObject.users.length; i++) {
        var trow = document.createElement("tr");
        for (var j = 0; j < 5; j++) {
          var td = document.createElement("td");
          switch (j) {
            case 0:
              td.innerHTML = responseObject.users[i].id;
              break;
            case 1:
              td.innerHTML = responseObject.users[i].first_name;
              break;
            case 2:
              td.innerHTML = responseObject.users[i].last_name;
              break;
            case 3:
              td.innerHTML = responseObject.users[i].banner_id;
              break;
            case 4:
              td.innerHTML = responseObject.users[i].email;
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
  xhttp.open("GET", database, true);
  xhttp.send();
}
