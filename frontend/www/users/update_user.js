function get_user_from_url(){
  var url = window.location + "";
  var point = url.indexOf("=");
  var user_id = url.substring(point+1, url.length);
  
  console.log("User ID is " + user_id);
  var xhttp = new XMLHttpRequest();
  xhttp.onreadystatechange = function() {
    if (this.readyState == 4 && this.status == 200) {
		var search_results =  JSON.parse(this.responseText);
    var user = "<tr><td> First name: </td><td> " + search_results.first_name + "</td></tr>" +
      "<tr><td> Last name: </td><td> " + search_results.last_name + "</td></tr>" +
      "<tr><td> Email: </td><td> " + search_results.email + "</td></tr>" +
      "<tr><td> Banner ID: </td><td> " + search_results.banner_id + "</td></tr>";
    document.getElementById("current_user").innerHTML = user;
  }};
  xhttp.open("GET", baseip+":8000/users/"+user_id,true);
  xhttp.send();
}
function update_user(){
  if (document.getElementById("firstname").value === ""){
	  fn = null;
  }else{
	 fn = document.getElementById("firstname").value;
  }

  if (document.getElementById("lastname").value===""){
    ln=null
  }
  else{
	  ln = document.getElementById("lastname").value;
  }
  if (document.getElementById("email").value===""){
	  em=null;
  }else{
	 em = document.getElementById("email").value;
  }
  if (document.getElementById("banner_id").value===""){
   bi=null
  }
  else{
	   bi = document.getElementById("banner_id").value;
  }
  var xhttp = new XMLHttpRequest();
  xhttp.onreadystatechange = function() {
  if (this.readyState == 4 && this.status == 204) {
    document.getElementById("result").innerHTML = "User Editted!";
     get_user_from_url();        
  } else {
    document.getElementById("result").innerHTML ="Error editted user";
  }}
  // Reaquire User
  var url = window.location + "";
  var point = url.indexOf("=");
  var user_id = url.substring(point+1, url.length);
  person = {first_name:fn , last_name:ln, banner_id:parseInt(bi), email:em };
  xhttp.open("POST", baseip+":8000/users/"+user_id, true);
  xhttp.send(JSON.stringify(person));
  console.log("Sent to database");
    
   
}

function delete_user() {
  var url = window.location + "";
  var point = url.indexOf("=");
  var user_id = url.substring(point+1, url.length);
  
  var xhttp = new XMLHttpRequest();
  xhttp.onreadystatechange = function() {
  if (this.readyState == 4 && this.status == 204) {
    document.getElementById("result").innerHTML = "User Deleted!";
    
  } else {
    document.getElementById("result").innerHTML ="Error deleting user";
  }}
  xhttp.open("DELETE", baseip+":8000/users/"+user_id, true);
  xhttp.send();
  
  

}