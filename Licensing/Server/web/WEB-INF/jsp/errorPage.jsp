<%@page contentType="text/html" pageEncoding="UTF-8"%><%@
include file="/WEB-INF/jsp/includes/include.jspf"
        %><!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
    <head>
        <title><spring:message code="smstickets.title"/></title>
        <link rel="shortcut icon" href='<c:url value="/favicon.ico"/>' type="image/x-icon">
        <link rel="icon" href='<c:url value="/css/favicon.ico"/>' type="image/x-icon">
    </head>
    
    <body>
        
        <h3><spring:message code="errorPage.title"/></h3>
        <spring:message code="errorPage.applicationError"/>
    </body>
</html>
