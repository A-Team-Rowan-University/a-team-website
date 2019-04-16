
function opennav() {

  document.getElementById("sidenav").style.width = "24em";// slides out side nav menu

  var path = window.location.pathname;
  var page = path.split("/").pop();//this gets the name of the document

  document.getElementById("sidenav").innerHTML = `
    <div id = closebutton>
      <a href="javascript:void(0)" class="closebtn" onclick="closenav()">&times;</a>
    </div>
    <a href="#" class = "dropdown">Index</a>
    <div id = linksDiv>somthing went wrong
    </div>
  `//this puts the indexlink and the links div where the if-else block bellow puts apporiate links in depeading on the document name

  if(page.includes("template")){


    document.getElementById("linksDiv").innerHTML = `
      <button class="accordionMenu"><span class = dropdown>People</span></button>
      <div class="panel">
        <a href="./PeopleDatabase/AllUsers.html">All Users</a>
        <a href="./PeopleDatabase/SearchUser">Search User</a>
        <a href="./PeopleDatabase/AddUsers.html">Add User</a>
        <a href="#">Edit User</a>
      </div>
      <button class="accordionMenu"><span class = dropdown>Chemicals</span></button>
      <div class="panel">
        <a href="./ChemicalDataBase/AllChemicals.html">All Chemicals</a>
        <a href="#">Search Chemical</a>
        <a href="#">Add Chemical</a>
        <a href="#">Edit Chemical</a>
      `
    }

    else if (page.includes("Users")) {
      document.getElementById("linksDiv").innerHTML = `
      <div id = linksDiv>
        <button class="accordionMenu"><span class = dropdown>People</span></button>
        <div class="panel">
          <a href="AllUsers.html">All Users</a>
          <a href="SearchUsers.html">Search User</a>
          <a href="AddUsers.html">Add User</a>
          <a href="#">Edit User</a>
        </div>
        <button class="accordionMenu"><span class = dropdown>Chemicals</span></button>
        <div class="panel">
          <a href="../ChemicalDataBase/AllChemicals.html">All Chemicals</a>
          <a href="#">Search Chemical</a>
          <a href="#">Add Chemical</a>
          <a href="#">Edit Chemical</a>
        `
    }
    else if (page.includes("Chemical")) {

      document.getElementById("linksDiv").innerHTML = `
        <button class="accordionMenu"><span class = dropdown>People</span></button>
        <div class="panel">
          <a href="../PeopleDatabase/AllUsers.html">All Users</a>
          <a href="../PeopleDatabase/SearchUsers.html">Search User</a>
          <a href="../PeopleDatabase/AddUsers.html">Add User</a>
          <a href="#">Edit User</a>
        </div>
        <button class="accordionMenu"><span class = dropdown>Chemicals</span></button>
        <div class="panel">
          <a href="AllChemicals.html">All Chemicals</a>
          <a href="#">Search Chemical</a>
          <a href="#">Add Chemical</a>
          <a href="#">Edit Chemical</a>
        `

    }
    else {
    }

    var acc = document.getElementsByClassName("accordionMenu");
    var i; /* finds every element with the class id accodian and addes them to a list */

      for (i = 0; i < acc.length; i++) {
        acc[i].addEventListener("click", function() {/* makes said elements open/close their respective drop down menu when clicked*/
          this.classList.toggle("active");
          var panel = this.nextElementSibling;
          if (panel.style.display === "block") {
            panel.style.display = "none";
          } else {
            panel.style.display = "block";
          }
      });
    }
}

function closenav()
{
  document.getElementById("sidenav").style.width = "0em";
}
