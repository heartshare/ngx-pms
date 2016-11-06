
# 权限规划
页面 | 匹配方式 | 需要权限 |权限说明
----|-----|----|-----
/en/ | 精确匹配 | ALLOW_ALL | 所有人可访问 | 
/en/download.html | 精确匹配 | OR_DL_IDX | 下载页首页
/en/download/ | 前缀匹配 | OR_DL_FILES | 下载文件权限
/en/installation.html | 精确匹配 |OR_INSTALL | 安装页权限
/en/getting-started.html |  精确匹配 |OR_GETSTART | 学习入门
/en/upgrading.html | 精确匹配 | OR_UPGRAD | 安装升级
/en/change | 前缀匹配 | OR_CHANGES | 更改日志
/en/components.html | 精确匹配 | OR_COMPONENT | 组件页
/en/community.html| 精确匹配 | OR_COMMUNITY | 社区
/en/benchmark.html| 精确匹配 | OR_BANCHMARK | 基准测试
/en/contact-us.html| 精确匹配 | OR_CONTACT_US | 联系我们
/en/about.html | 精确匹配 | OR_ABOUT | 关于我们
/en/debugging.html| 精确匹配 | OR_DEBUGGING | 调试
/cn/ | 前缀匹配 | OR_CN_ALL | OR中文所有
/images | 前缀匹配 | ALLOW_ALL | 所有人可访问 | 
/css | 前缀匹配 | ALLOW_ALL | 所有人可访问 | 
/ | 前缀匹配 | DENY_ALL | 所有人不可访问 | 

# 角色规划
角色ID | 角色名称 | 包含的权限 
---|----|----
OR_DL | 下载安装升级 | OR_DL_IDX,OR_INSTALL, OR_UPGRAD
OR_CONTACT_ABOUT | 关于&关系我们 | OR_CONTACT_US, OR_ABOUT
