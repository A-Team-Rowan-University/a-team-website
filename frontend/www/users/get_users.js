function get_users() {
  var x, fn, ln,y;
  var people;
  //people.id = "seach_table";
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
  var xhttp = new XMLHttpRequest();
  xhttp.onreadystatechange = function() {
    if (this.readyState == 4 && this.status == 200) {
		var search_results =  JSON.parse(this.responseText);
		var search_table = document.createElement("TABLE");
		people = "<tr> <th> Row </th><th> First Name </th><th>Last Name</th><th> Email </th></tr>";
		for(x in search_results.users){
			//people += search_results.users[x].first_name+ " " + search_results.users[x].last_name + ", email: "+search_results.users[x].email+"<br>";
			y=parseInt(x)+1;
			people += "<tr> <td>"+ y +"</td><td>"+search_results.users[x].first_name+ "</td><td>" + search_results.users[x].last_name 
			+ "</td><td>"+search_results.users[x].email+"</td><td>" + 
      "<input type=\"button\" onclick=\"location.href=\'/users/edit.html?user_id="+search_results.users[x].id+"\'\" value=\"Edit\"/></td></tr>";
		}
		document.getElementById("user").innerHTML = people;
	}
  };
  console.log("first name: \""+fn + "\" lastname: \"" + ln+"\"");
  if (fn !=="" && ln !==""){ 
	xhttp.open("GET", baseip+"/users/?first_name_exact="+fn+"&last_name_exact="+ln, true);
  }else if(fn !==""){
	xhttp.open("GET", baseip+"/users/?first_name_exact="+fn, true);  
  }else if(ln !==""){
	  xhttp.open("GET", baseip+"/users/?last_name_exact="+ln, true);
  }else {
	  console.log("Empty Search");
	  xhttp.open("GET", baseip+"/users/", true);
  }
  xhttp.send();
}
