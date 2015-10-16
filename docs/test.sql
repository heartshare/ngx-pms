show tables;
select * from user;
select * from permission;
select * from url_perm;

insert into url_perm(app,type,url,url_len, permission) 
values('news', 'equal', '/index.html', length(url), 'NEWS_INDEX');

insert into url_perm(app,type,url,url_len, permission) 
values('news', 'suffix', '.jpg', length(url), 'NEWS_JPG');

insert into url_perm(app,type,url,url_len, permission) 
values('news', 'prefix', '/Image', length(url), 'NEWS_IMAGE');

SELECT id,app,type,url,url_len,permission 
FROM url_perm where app='news' and type='equal' and url = '/Image/index.html'

SELECT id,app,type,url,url_len,permission 
FROM url_perm where app='news' and type='suffix' and 
url = right('/Image/index.html', length(url)) order by url_len desc limit 1

SELECT id,app,type,url,url_len,permission 
FROM url_perm where app='news' and type='prefix' and 
url = substr('/Image/index.html', 1, length(url)) order by url_len desc limit 1

SELECT id,app,type,url,url_len,permission 
FROM url_perm;

