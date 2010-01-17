<%@page contentType="text/html" pageEncoding="UTF-8"%><%@
include file="/WEB-INF/jsp/includes/include.jspf"
        %><?xml version="1.0" encoding="UTF-8" ?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
    <head>
        <meta http-equiv="Content-Type" content="text/html; charset=UTF-8" />
        <title>SMS jízdenka</title>
        <link rel="stylesheet" type="text/css" href='<c:url value="/css/admin.css"/>' />
    </head>
    <body>
        <div id="holder_login">
            <form:form modelAttribute="loginData">
                <div id="loginbox">
                    <label for="userName" class="label"><spring:message code="management.login.userName"/></label><br/>
                    <form:input path="userName" cssClass="linput"/><br/>
                    <label for="userPassword" class="label"><spring:message code="management.login.userPassword"/></label><br/>
                    <form:password path="userPassword" cssClass="linput"/><br/>
                </div>
                <input type="submit" id="lbutton" value='<spring:message code="management.login.submit"/>'/>
            </form:form>
        </div>
    </body>
</html>