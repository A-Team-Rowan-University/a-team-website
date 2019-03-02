var baseip="http://192.168.176.129";

function load_header() {
  console.log("Loading Header");
  var xhttp = new XMLHttpRequest();
  xhttp.open('GET', '/header.html');
  xhttp.onreadystatechange = function() {
    document.getElementById("navbar").innerHTML=xhttp.responseText;
  }
  xhttp.send();
}
window.onload = load_header;