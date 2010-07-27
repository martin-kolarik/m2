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
                        <li><a href="ticketreport.do">Jízdenky</a></li>
                        <li><a href="controllers.do" class="b4act">Revizoři</a></li>
                        <li><a href="devices.do" class="act">MDA zařízení</a></li>
                    </ul>
                </div>
            </div>
            <div id="content">
                <h1><spring:message code="management.devicedetail.title"/> — ${device.name}</h1>
                
                <div class="frame">
                    <a class="close" href='<c:url value="/management/devices.do"/>'><spring:message code="management.devicedetail.close"/></a>
                    <strong><spring:message code="management.devicedetail.detail"/></strong>
                </div>
                
                <h2>Základní informace</h2>
                
                <form:form modelAttribute="device">
                    <div class="error-list">
                        <form:errors cssClass="errors"/>
                    </div>
                    
                    <table id="ticketinfo">
                        <tr>
                            <th><spring:message code="management.devicedetail.company"/></th>
                            <td>${device.controller.company.name}</td>
                            <td>&nbsp;</td>
                        </tr>
                        <tr class="even">
                            <c:choose>
                                <c:when test="${device.controller!=null}">
                                    <th><spring:message code="management.devicedetail.controller"/></th>
                                    <td>
                                        <a href="<c:url value="/management/editcontroller.do?id=${device.controller.controllerId}"/>">
                                            ${device.controller.firstName} ${device.controller.lastName}
                                        </a>
                                    </td>
                                    <td>
                                        <c:choose>
                                            <c:when test="${operatorUserPrincipal.operator.type=='OPERATOR'}">
                                                <form:checkbox path="unlinkController" id="lcheck"/>
                                                <spring:message code="management.devicedetail.unlinkController"/>
                                            </c:when>
                                            <c:otherwise>
                                                &nbsp;
                                            </c:otherwise>
                                        </c:choose>
                                    </td>
                                </c:when>
                                <c:otherwise>
                                    <th><spring:message code="management.devicedetail.controller"/></th>
                                    <td>&nbsp;</td>
                                    <td>&nbsp;</td>
                                </c:otherwise>
                            </c:choose>
                        </tr>
                        <tr>
                            <th><spring:message code="management.devicedetail.code"/></th>
                            <td>${device.code}</td>
                            <td>&nbsp;</td>
                        </tr>
                        <tr class="even">
                            <th><spring:message code="management.devicedetail.name"/></th>
                            <td id="kod">
                                <c:choose>
                                    <c:when test="${operatorUserPrincipal.operator.type=='OPERATOR'}">
                                        <form:input path="name"/>
                                        <form:errors cssClass="errors" path="name"/>
                                    </c:when>
                                    <c:otherwise>
                                    ${device.name}
                                    </c:otherwise>
                                </c:choose>
                            </td>
                            <td>&nbsp;</td>
                        </tr>
                        <tr>
                            <th><spring:message code="management.devicedetail.active"/></th>
                            <td>
                                <c:choose>
                                    <c:when test="${operatorUserPrincipal.operator.type=='OPERATOR'}">
                                        <form:select path="active">
                                            <form:option value="true"><spring:message code="management.devicedetail.active.yes"/></form:option>
                                            <form:option value="false"><spring:message code="management.devicedetail.active.no"/></form:option>
                                        </form:select>
                                    </c:when>
                                    <c:otherwise>
                                        <c:choose>
                                            <c:when test="${device.active}">
                                                <spring:message code="management.devicedetail.active.yes"/>
                                            </c:when>
                                            <c:otherwise>
                                                <spring:message code="management.devicedetail.active.no"/>
                                            </c:otherwise>
                                        </c:choose>
                                    </c:otherwise>
                                </c:choose>
                            </td>
                            <td>&nbsp;</td>
                        </tr>
                    </table>
                    
                    <c:if test="${operatorUserPrincipal.operator.type=='OPERATOR'}">
                        <p>
                            <input id="fhledat" type="submit" value='<spring:message code="management.devicedetail.accept"/>'/>
                        </p>
                    </c:if>
                </form:form>
                
                <div class="frame">
                    <a class="close" href='<c:url value="/management/devices.do"/>'><spring:message code="management.devicedetail.close"/></a>
                    <strong><spring:message code="management.devicedetail.detail"/></strong>
                </div>
                
            </div>
        </div>
    </body>
</html>


