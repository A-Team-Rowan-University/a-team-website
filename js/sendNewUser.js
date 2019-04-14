function sendNewUser()
{
  var firstNameInput = document.getElementById("first_name");
  var lastNameInput = document.getElementById("last_name");
  var bannerIdInput = document.getElementById("banner_id");
  var newUser = {
    first_name : firstNameInput.value,
    last_name : lastNameInput.value,
    banner_id : parseInt(bannerIdInput.value)
  }
  console.log(newUser);
  var xhttp = new XMLHttpRequest();
  xhttp.open("POST", database, true);
  xhttp.setRequestHeader('Content-Type', 'application/json; charset=UTF-8');
  xhttp.send(JSON.stringify(newUser));
}
