function opennav() {
  document.getElementById("sidenav").style.width = "24em";// slides out side nav menu

}

function updatelinks() {

  var path = window.location.pathname;
  var page = path.split("/").pop();
  alert(page);

/*  document.getElementById("sidenav") = `<div id="sidenav" class="sidenav">
  <div id = closebutton>
    <a href="javascript:void(0)" class="closebtn" onclick="closenav()">&times;</a>
  </div>
  <div id = linksDiv>
    <a href="#" class = "dropdown">Index</a>
    <button class="accordionMenu"><span class = dropdown>People</span></button>
    <div class="panel">
      <a href="PeopleDatabase/AllUsers.html">All Users</a>
      <a href="PeopleDatabase/SearchUser">Search User</a>
      <a href="PeopleDatabase/AddUsers.html">Add User</a>
      <a href="#">Edit User</a>
    </div>
    <button class="accordionMenu"><span class = dropdown>Chemicals</span></button>
    <div class="panel">
      <a href="PeopleDatabase/">All Chemicals</a>
      <a href="#">Search Chemical</a>
      <a href="#">Add Chemical</a>
      <a href="#">Edit Chemical</a>
    </div>
    </div>`*/

}

function sideNavDropDown(){
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

function sideUpdate(){

  document.getElementById("container").innerHTML = "bloop";



}
