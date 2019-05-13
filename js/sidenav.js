
function opennav() {

  document.getElementById("sidenav").style.width = "24em";// slides out side nav menu

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
