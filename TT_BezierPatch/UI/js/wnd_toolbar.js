// ...

$(document).ready(build_UI);

// http://blogs.msdn.com/ie/archive/2008/10/06/updates-for-ajax-in-ie8-beta-2.aspx#8987062
// file:///C:/Users/Thomas/AppData/Local/Temp/skpAD1E.tmp#


function build_UI()
{
	var body = $('body');
	
  var item1 = $('<div class="button"></div>').appendTo(body);
  item1.attr('title', 'Select');
  var img1 = $('<img src="file:///C:/Users/Thomas/Sketchup Plugins/Bezier Patch/TT_BezierPatch/UI/Icons/Select_24.png" alt="NA">').appendTo(item1);
  
  var item2 = $('<div class="button"></div>').appendTo(body);
  item2.attr('title', 'Move');
  var img2 = $('<img src="file:///C:/Users/Thomas/Sketchup Plugins/Bezier Patch/TT_BezierPatch/UI/Icons/Move_24.png" alt="NA">').appendTo(item2);
  
  var item3 = $('<div class="list">Axis: </div>').appendTo(body);
  var lst_axis = $('<select></select>').appendTo(item3);
  $('<option>Local</option>').appendTo(lst_axis);
  $('<option>Global</option>').appendTo(lst_axis);
  $('<option>Custom</option>').appendTo(lst_axis);
  
  //alert( $('html').html() );
}

//alert(document.documentMode);