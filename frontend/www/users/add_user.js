function add_user(){
  var fn, ln, em, bi, person
  
  if (document.getElementById("firstname")){
	  fn = document.getElementById("firstname").value;
  }else{
	 fn = "";
  }
  if (document.getElementById("lastname")){
    ln = document.getElementById("lastname").value;
  }
  else{
	  ln="";
  }
  if (document.getElementById("email")){
	  em = document.getElementById("email").value;
  }else{
	 em = "";
  }
  if (document.getElementById("banner_id")){
    bi = document.getElementById("banner_id").value;
  }
  else{
	  bi="";
  }
  console.log(fn + ", " + ln + ": " + em + " " + bi);
  var xhttp = new XMLHttpRequest();
  xhttp.onreadystatechange = function() {
  if (this.readyState == 4 && this.status == 200) {
    document.getElementById("result").innerHTML = "User added!";
  } else {
    document.getElementById("result").innerHTML ="Error adding user";
  }
  }
  if (fn !== "" | ln !== "" | bi !== ""){
    person = {first_name:fn , last_name:ln, banner_id:parseInt(bi), email:em };
    xhttp.open("POST", baseip+"/users/", true);
    xhttp.send(JSON.stringify(person));
    console.log("Sent to database");
  }else{
    document.getElementById("result").innerHTML ="Error: First name, Last name, and Banner ID are required";
    console.log("Error in text fields");
  }

}
