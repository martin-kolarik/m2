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
        <div id="holder">
            <div id="top">
                <a id="logo" href="/">Dopravní podnik hlavního města Prahy<span></span></a>
                <dl>
                    <dt><c:out value="${operatorUserPrincipal.operator.lastName}"/></dt>
                    <dd><a href="logout.do">odhlášení</a>
                </dl>
            </div>
            <div id="menu">
                <div>
                    <ul>
                        <li><a href="timeload.do">Přehled</a></li>
                        <li><a href="ticketreport.do" class="b4act">Jízdenky</a></li>
                        <li><a href="controllers.do" class="act">Revizoři</a></li>
                        <li><a href="devices.do">MDA zařízení</a></li>
                    </ul>
                </div>
            </div>
            <div id="content">
                <h1><spring:message code="management.controllerdetail.title"/> — ${controller.firstName} ${controller.lastName} (${controller.userName})</h1>
                <div class="frame">
                    <a class="close" href='<c:url value="/management/controllers.do"/>'><spring:message code="management.ticketdetail.close"/></a>
                    <strong><spring:message code="management.controllerchecks.detail"/></strong>
                    <span>|</span>
                    <a href="<c:url value="/management/controllerchecks.do?id=${controller.controllerId}"/>"><spring:message code="management.controllerdetail.checks"/></a>                    
                </div>
                
                <h2>Základní informace</h2>
                <form:form modelAttribute="controller">
                    <div class="error-list">
                        <form:errors cssClass="errors"/>
                    </div>
                    <table id="ticketinfo">
                        <tr>
                            <th><spring:message code="management.controllerdetail.company"/></th>
                            <td>${controller.company.name}</td>
                        </tr>
                        <tr class="even">
                            <th><spring:message code="management.controllerdetail.controllerGroup"/></th>
                            <td>
                                <c:choose>
                                    <c:when test="${operatorUserPrincipal.operator.type=='OPERATOR'}">
                                        <form:select path="controllerGroup">
                                            <form:options items="${controllerGroups}" itemValue="controllerGroupId" itemLabel="name"/>
                                        </form:select>
                                    </c:when>
                                    <c:otherwise>
                                    ${controller.controllerGroup.name}
                                    </c:otherwise>
                                </c:choose>
                            </td>
                        </tr>
                        <tr>
                            <th><spring:message code="management.controllerdetail.number"/></th>
                            <td>
                                <c:choose>
                                    <c:when test="${operatorUserPrincipal.operator.type=='OPERATOR'}">
                                        <form:input path="phoneNumber"/>
                                        <form:errors cssClass="errors" path="phoneNumber"/>
                                    </c:when>
                                    <c:otherwise>
                                    ${controller.phoneNumber}
                                    </c:otherwise>
                                </c:choose>
                            </td>
                        </tr>
                        <tr class="even">
                            <th><spring:message code="management.controllerdetail.firstName"/></th>
                            <td>
                                <c:choose>
                                    <c:when test="${operatorUserPrincipal.operator.type=='OPERATOR'}">
                                        <form:input path="firstName"/>
                                        <form:errors cssClass="errors" path="firstName"/>
                                    </c:when>
                                    <c:otherwise>
                                    ${controller.firstName}
                                    </c:otherwise>
                                </c:choose>
                            </td>
                        </tr>
                        <tr>
                            <th><spring:message code="management.controllerdetail.lastName"/></th>
                            <td>
                                <c:choose>
                                    <c:when test="${operatorUserPrincipal.operator.type=='OPERATOR'}">
                                        <form:input path="lastName"/>
                                        <form:errors cssClass="errors" path="lastName"/>
                                    </c:when>
                                    <c:otherwise>
                                    ${controller.lastName}
                                    </c:otherwise>
                                </c:choose>
                            </td>
                        </tr>
                        <tr class="even">
                            <th><spring:message code="management.controllerdetail.code"/></th>
                            <td id="kod">
                                <c:choose>
                                    <c:when test="${operatorUserPrincipal.operator.type=='OPERATOR'}">
                                        <form:input path="userName"/>
                                        <form:errors cssClass="errors" path="userName"/>
                                    </c:when>
                                    <c:otherwise>
                                    ${controller.userName}
                                    </c:otherwise>
                                </c:choose>
                            </td>
                        </tr>
                        <c:if test="${operatorUserPrincipal.operator.type=='OPERATOR'}">
                            <tr>
                                <th><spring:message code="management.controllerdetail.password"/></th>
                                <td><form:input path="newPassword"/>
                                <form:errors cssClass="errors" path="newPassword"/></td>
                            </tr>
                        </c:if>
                        <tr class="even">
                            <th><spring:message code="management.controllerdetail.active"/></th>
                            <td>
                                <c:choose>
                                    <c:when test="${operatorUserPrincipal.operator.type=='OPERATOR'}">
                                        <form:select path="active">
                                            <form:option value="true"><spring:message code="management.controllerdetail.active.yes"/></form:option>
                                            <form:option value="false"><spring:message code="management.controllerdetail.active.no"/></form:option>
                                        </form:select>
                                    </c:when>
                                    <c:otherwise>
                                        <c:choose>
                                            <c:when test="${controller.active}">
                                                <spring:message code="management.controllerdetail.active.yes"/>
                                            </c:when>
                                            <c:otherwise>
                                                <spring:message code="management.controllerdetail.active.no"/>
                                            </c:otherwise>
                                        </c:choose>
                                    </c:otherwise>
                                </c:choose>
                            </td>
                        </tr>
                        
                    </table>
                    <c:if test="${operatorUserPrincipal.operator.type=='OPERATOR'}">
                        <p>
                            <input id="fhledat" type="submit" value='<spring:message code="management.controllerdetail.accept"/>'/>
                        </p>
                    </c:if>
                </form:form>
                
                <c:choose>
                    <c:when test="${not empty controller.devices}">
                    
                        <table id="grid">
                            <thead>
                                <tr>
                                    <td><spring:message code="management.controllerdetail.table.deviceName"/></td>
                                    <td><spring:message code="management.controllerdetail.table.deviceCode"/></td>
                                    <td></td>
                                </tr>
                            </thead>
                            <c:forEach items="${controller.devices}" var="device" varStatus="status">
                                <c:choose>
                                    <c:when test='${(status.index)%2 eq 0}'>                                
                                        <tr>
                                    </c:when>
                                    <c:otherwise>
                                        <tr class="even">
                                        </c:otherwise>
                                    </c:choose>
                                    <td>
                                        ${device.name}
                                    </td>
                                    <td>
                                        <a href="<c:url value="/management/editdevice.do?id=${device.deviceId}"/>">${device.code}</a>
                                    </td>
                                    <td>
                                        <c:choose>
                                            <c:when test="${operatorUserPrincipal.operator.type=='OPERATOR'}">
                                                <a href="<c:url value="/management/unlinkdevicefromcontroller.do?id=${device.deviceId}"/>"><spring:message code="management.controllerdetail.unlinkDevice"/></a>
                                            </c:when>
                                            <c:otherwise>
                                                &nbsp;
                                            </c:otherwise>
                                        </c:choose>
                                    </td>                                   
                                </tr>
                            </c:forEach>
                        </table>
                    </c:when>
                    <c:otherwise>
                        <p>
                            <spring:message code="management.controllerdetail.nodevice"/>
                        </p>
                    </c:otherwise>
                </c:choose>
                
                <div class="frame">
                    <a class="close" href='<c:url value="/management/controllers.do"/>'><spring:message code="management.ticketdetail.close"/></a>
                    <strong>Detail</strong>
                    <span>|</span>
                    <a href="<c:url value="/management/controllerchecks.do?id=${controller.controllerId}"/>"><spring:message code="management.controllerdetail.checks"/></a>                    
                </div>
                
            </div>
        </div>
    </body>
</html>
