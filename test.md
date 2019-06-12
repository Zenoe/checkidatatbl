# API
---

### 实时统计当前（累计）在线人数或终端

---
    get /user/statistics/getRealtimeStatistics
    
    参数：
	{
	}
    
    返回: 
        {
            "success": true,
            "code": 200,
            "message": null,
            "messageDetail": null,
            "throwable": null,
            "data": {
                "daily_sta_num": 470, //当天累计在线终端数
                "ymd": "20190605", // 日期
                "show_time": "201906051800", // 展示时间
                "cal_time": 1559728500000, // 计算时间
                "daily_valid_sta_num": 440, // 当天累计有效无线终端数
                "realtime_user_num": 30, // 当前在线用户数
                "valid_realtime_sta_num": 24, // 当前有效接入终端数
                "daily_user_num": 450, // 当天累计用户数
                "invalid_realtime_sta_num": 29, // 但前无效接入终端数
                "realtime_sta_num": 50, // 实时在线终端数
                "daily_invalid_sta_num": 760 // 当天累计无效无线终端数
            }
        }
---

### 查询认证用户数量变化趋势
---
    post /user/statistics/getUserOnlineCountTrend
    
    参数:
        {
            "startDay":"20190512",
            "endDay": "20190522"
        }
        
    返回:
        {
            "success": true,
            "code": 200,
            "message": null,
            "messageDetail": null,
            "throwable": null,
            "data": [
                {
                    "ymd": "20190515",
                    "daily_user_num": 72
                },
                {
                    "ymd": "20190516",
                    "daily_user_num": 67
                },
                {
                    "ymd": "20190517",
                    "daily_user_num": 150
                },
                {
                    "ymd": "20190518",
                    "daily_user_num": 250
                },
                {
                    "ymd": "20190519",
                    "daily_user_num": 450
                },
                {
                    "ymd": "20190520",
                    "daily_user_num": 420
                }
            ]
        }
---

### 查询认证终端数量变化趋势
---
    post /user/statistics/getStaCountTrend
    
    参数：
        {
            "startDay":"20190512",
            "endDay": "20190522"
        }
        
    返回：
        {
            "success": true,
            "code": 200,
            "message": null,
            "messageDetail": null,
            "throwable": null,
            "data": [
                {
                    "daily_sta_num": 89,
                    "ymd": "20190515"
                },
                {
                    "daily_sta_num": 90,
                    "ymd": "20190516"
                },
                {
                    "daily_sta_num": 190,
                    "ymd": "20190517"
                },
                {
                    "daily_sta_num": 270,
                    "ymd": "20190518"
                },
                {
                    "daily_sta_num": 470,
                    "ymd": "20190519"
                },
                {
                    "daily_sta_num": 490,
                    "ymd": "20190520"
                }
            ]
        }
---

### 查询有效、无效无线终端数量变化趋势
---
    post /user/statistics/getWirelessStaCountTrend
        
    参数：
        {
            "startDay":"20190512",
            "endDay": "20190522"
        }
        
    返回：
        {
            "success": true,
            "code": 200,
            "message": null,
            "messageDetail": null,
            "throwable": null,
            "data": [
                {
                    "ymd": "20190515",
                    "daily_valid_sta_num": 70,
                    "daily_invalid_sta_num": 90
                },
                {
                    "ymd": "20190516",
                    "daily_valid_sta_num": 60,
                    "daily_invalid_sta_num": 79
                },
                {
                    "ymd": "20190517",
                    "daily_valid_sta_num": 140,
                    "daily_invalid_sta_num": 160
                },
                {
                    "ymd": "20190518",
                    "daily_valid_sta_num": 240,
                    "daily_invalid_sta_num": 360
                },
                {
                    "ymd": "20190519",
                    "daily_valid_sta_num": 440,
                    "daily_invalid_sta_num": 760
                },
                {
                    "ymd": "20190520",
                    "daily_valid_sta_num": 400,
                    "daily_invalid_sta_num": 630
                }
            ]
        }
