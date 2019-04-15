function opennav() {
  document.getElementById("sidenav").style.width = "24em";// slides out side nav menu

}

function updateLinks() {

 var path = window.location.pathname;
 var page = path.split("/").pop();//this gets the name of the document

 if(page.includes("template")){

   document.getElementById("sidenav").innerHTML = `
   <div id = closebutton>
     <a href="javascript:void(0)" class="closebtn" onclick="closenav()">&times;</a>
   </div>
   <div id = linksDiv>
     <a href="#" class = "dropdown">Index</a>
     <button class="accordionMenu"><span class = dropdown>People</span></button>
     <div class="panel">
       <a href="./PeopleDatabase/AllUsers.html">All Users</a>
       <a href="./PeopleDatabase/SearchUser">Search User</a>
       <a href="./PeopleDatabase/AddUsers.html">Add User</a>
       <a href="#">Edit User</a>
     </div>
     <button class="accordionMenu"><span class = dropdown>Chemicals</span></button>
     <div class="panel">
       <a href="PeopleDatabase/">All Chemicals</a>
       <a href="#">Search Chemical</a>
       <a href="#">Add Chemical</a>
       <a href="#">Edit Chemical</a>
     </div>
     `
   }

   else if (page.includes("Users")) {
     document.getElementById("sidenav").innerHTML = `
     <div id = closebutton>
       <a href="javascript:void(0)" class="closebtn" onclick="closenav()">&times;</a>
     </div>
     <div id = linksDiv>
       <a href="#" class = "dropdown">Index</a>
       <button class="accordionMenu"><span class = dropdown>People</span></button>
       <div class="panel">
         <a href="AllUsers.html">All Users</a>
         <a href="SearchUsers.html">Search User</a>
         <a href="AddUsers.html">Add User</a>
         <a href="#">Edit User</a>
       </div>
       <button class="accordionMenu"><span class = dropdown>Chemicals</span></button>
       <div class="panel">
         <a href="PeopleDatabase/">All Chemicals</a>
         <a href="#">Search Chemical</a>
         <a href="#">Add Chemical</a>
         <a href="#">Edit Chemical</a>
       </div>
       `
   }
   else if (page.includes("Chemical")) {

     document.getElementById("sidenav").innerHTML = `if your reading this you problbly tried to place the html for the Chemical side nav in one of the chemicals html documents
     please change the fillier text your now seeing in sidenav.js to use the side nav bar`

   }
   else {

   }
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
