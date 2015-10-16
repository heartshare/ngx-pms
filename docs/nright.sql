create database nright character set utf8;

use nright;

create table `user` (
	id integer primary key,
	username varchar(64) not null,
	email varchar(128) not null,
	password varchar(64) not null comment '密码的md5值',
	role_id varchar(32) null comment '角色ID，只能有一个角色',
	permission varchar(4096) null comment '权限列表，使用|分割',
  create_time integer unsigned comment '创建时间',
  update_time integer unsigned comment '修改时间',
	unique key(username),
	unique key(email)
) engine=innodb comment='用户表';

create table `permission` (
	id varchar(32) primary key comment '权限ID，使用字母，下划线',
	name varchar(64) not null comment '权限名称',
	remark varchar(128) null comment '备注说明',
  create_time integer unsigned comment '创建时间',
  update_time integer unsigned comment '修改时间',
	unique key(name)
) engine=innodb comment='权限表';
 
create table `role` (
	id varchar(32) primary key comment '字符串类型的角色ID',
	name varchar(64) not null comment '权限名称',
	remark varchar(128) null comment '备注说明',
	permission varchar(4096) null comment '权限列表，使用|分割',
  create_time integer unsigned comment '创建时间',
  update_time integer unsigned comment '修改时间',
	unique key(name)
) engine=innodb comment='角色表';

create table `url_perm` (
	id bigint unsigned auto_increment comment 'urlid',
	app varchar(64) not null comment '应用标识',
	type varchar(16) not null comment 'url匹配类型包含以下几种：
  1.equal 精确匹配
  2.suffix 后缀匹配
  3.prefix 前缀匹配(最大匹配原则)
  4.regex 正则匹配(后期支持)
  匹配时，equal优先匹配，未匹配上时，
  使用suffix匹配，然后是prefix，最后是regex
',
	url varchar(256) not null comment 'URL',
  url_len smallint default 0 comment 'url长度, 用作优先级，匹配时，
  使用最大匹配原则，所以长度越大，优先级越高',
	permission varchar(32) null comment '访问需要的权限，NULL表示任何人可访问',
  create_time integer unsigned comment '创建时间',
  update_time integer unsigned comment '修改时间',
  primary key(id),
  unique key(app,type,url(200))
) engine=innodb comment='URL权限表';