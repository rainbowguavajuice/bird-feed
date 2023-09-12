const paths = ["https://rainbowguavajuice.github.io/bird-feed/permalink/20230910A.html","https://rainbowguavajuice.github.io/bird-feed/permalink/20230507A.html"];
function goto_random_post () {
	 window.location = paths[Math.floor(Math.random()*paths.length)];
}