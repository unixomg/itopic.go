<!DOCTYPE html>
<html lang="zh-CN">
<head>
	<meta charset="utf-8">
	<meta http-equiv="X-UA-Compatible" content="IE=edge">
	<meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1,user-scalable=no">
    <title>{{.title}}</title>
    <link rel="stylesheet" href="/static/css/markdown.css">
</head>
<body>
<div id="wrapper">
<h1>{{.title}}</h1>
{{range .topics}}
    <li><a href="/{{.TopicId}}.html">{{.Title}}</a></li>
{{end}}
</div>
</body>
</html>