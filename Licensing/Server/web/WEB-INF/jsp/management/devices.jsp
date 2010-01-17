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
                <h1><spring:message code="management.devices.title"/></h1>
                
                <form:form modelAttribute="devicesData">
                
                    <div class="error-list">
                        <form:errors cssClass="errors"/>
                    </div>
                    
                    <div class="gfilter">
                        <label for="fwords"><spring:message code="management.devices.filterWords"/></label>
                        <form:input path="filterWords" id="fwords" cssClass="tinput"/> 
                        <form:errors cssClass="errors" path="filterWords"/>
                        
                        <input type="submit" id="fhledat" value='<spring:message code="management.devices.submit"/>'/>
                    </div>
                    
                    
                    <div id="listtype">
                        <c:choose>
                            <c:when test='${devicesData.filter.category=="all"}'>
                                <strong><spring:message code="management.devices.category.all"/></strong>
                                <span>|</span>
                                <a href='<c:url value="/management/devices.do?category=active"/>'><spring:message code="management.devices.category.active"/></a>
                                <span>|</span>
                                <a href='<c:url value="/management/devices.do?category=inactive"/>'><spring:message code="management.devices.category.inactive"/></a>
                            </c:when>
                            <c:when test='${devicesData.filter.category=="active"}'>
                                <a href='<c:url value="/management/devices.do?category=all"/>'><spring:message code="management.devices.category.all"/></a>
                                <span>|</span>
                                <strong><spring:message code="management.devices.category.active"/></strong>
                                <span>|</span>
                                <a href='<c:url value="/management/devices.do?category=inactive"/>'><spring:message code="management.devices.category.inactive"/></a>
                            </c:when>
                            <c:when test='${devicesData.filter.category=="inactive"}'>
                                <a href='<c:url value="/management/devices.do?category=all"/>'><spring:message code="management.devices.category.all"/></a>
                                <span>|</span>
                                <a href='<c:url value="/management/devices.do?category=active"/>'><spring:message code="management.devices.category.active"/></a>
                                <span>|</span>
                                <strong><spring:message code="management.devices.category.inactive"/></strong>
                            </c:when>
                            <c:otherwise>
                                <a href='<c:url value="/management/devices.do?category=all"/>'><spring:message code="management.devices.category.all"/></a>
                                <span>|</span>
                                <a href='<c:url value="/management/devices.do?category=active"/>'><spring:message code="management.devices.category.active"/></a>
                                <span>|</span>
                                <a href='<c:url value="/management/devices.do?category=inactive"/>'><spring:message code="management.devices.category.inactive"/></a>
                            </c:otherwise>
                        </c:choose>
                    </div>
                    
                </form:form>
                
                <div id="clear">&nbsp;</div>
                
                
                <c:choose>
                    <c:when test="${devicesData.result.hasData}">
                    
                        <table id="grid">
                            <thead>
                                <tr>
                                    <c:forEach var="orderKey" items="${orderKeys}">
                                        <c:choose>
                                            <c:when test="${!pager.sortable[orderKey]}">
                                                <td>
                                                    <spring:message code="management.devices.table.${orderKey}"/>
                                                </td>
                                            </c:when>
                                            <c:when test="${pager.displayOrderedBy[orderKey] == null}">
                                                <td><a href="<c:url value="?order=${orderKey}"/>">
                                                        <spring:message code="management.devices.table.${orderKey}"/>
                                                </a></td>
                                            </c:when>
                                            <c:when test="${pager.displayOrderedBy[orderKey]}">
                                                <td><a class="up" href="<c:url value="?order=${orderKey}.desc"/>">
                                                        <spring:message code="management.devices.table.${orderKey}"/>
                                                </a></td>
                                            </c:when>
                                            <c:otherwise>
                                                <td><a class="down" href="<c:url value="?order=${orderKey}"/>">
                                                        <spring:message code="management.devices.table.${orderKey}"/>
                                                </a></td>
                                            </c:otherwise>
                                        </c:choose>
                                    </c:forEach>
                                </tr>
                            </thead>
                            
                            <c:forEach var="device" items="${devicesData.result.data}" varStatus="status">
                                <c:choose>
                                    <c:when test='${(status.index)%2 eq 0}'>                                
                                        <tr>
                                    </c:when>
                                    <c:otherwise>
                                        <tr class="even">
                                        </c:otherwise>
                                    </c:choose>
                                    <th>${device.name}</th>
                                    <td class="red"><a href="<c:url value="/management/editdevice.do?id=${device.id}"/>">${device.code}</a></td>
                                    <td><a href="<c:url value="/management/editcontroller.do?id=${device.controller.id}"/>">${device.controller.fullName}</a></td>
                                    <td>
                                        <c:choose>
                                            <c:when test="${device.active}">
                                                <spring:message code="management.devices.active"/>
                                            </c:when>
                                            <c:otherwise>
                                                <spring:message code="management.devices.inactive"/>
                                            </c:otherwise>
                                        </c:choose>    
                                    </td>
                                </tr>
                            </c:forEach>
                        </table>
                        
                        <p><%@include file="/WEB-INF/jsp/includes/pager.jsf"%></p>
                        
                        
                    </c:when>
                    <c:otherwise>
                        <p>
                            <spring:message code="management.ticketreport.nodata"/>
                        </p>
                    </c:otherwise>
                </c:choose>
                
            </div>
        </div>
    </body>
</html>