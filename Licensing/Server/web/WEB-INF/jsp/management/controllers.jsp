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
                <h1><spring:message code="management.controllers.title"/></h1>
                <form:form modelAttribute="controllersData">
                
                    <div class="error-list">
                        <form:errors cssClass="errors"/>
                    </div>
                    
                    <div class="gfilter">
                        <label for="fword"><spring:message code="management.controllers.filterWords"/></label>
                        <form:input path="filterWords" id="fword"/> 
                        <form:errors cssClass="errors" path="filterWords"/>
                        
                        <input type="submit" id="fhledat" value='<spring:message code="management.controllers.submit"/>'/>
                    </div>
                    
                    <div id="listtype">
                        <c:choose>
                            <c:when test='${controllersData.filter.category=="all"}'>
                                <strong>Vše</strong>
                                <span>|</span>
                                <a href='<c:url value="/management/controllers.do?category=active"/>'>Aktivní</a>
                                <span>|</span>
                                <a href='<c:url value="/management/controllers.do?category=inactive"/>'>Neaktivní</a>
                            </c:when>
                            <c:when test='${controllersData.filter.category=="active"}'>
                                <a href='<c:url value="/management/controllers.do?category=all"/>'>Vše</a>
                                <span>|</span>
                                <strong>Aktivní</strong>
                                <span>|</span>
                                <a href='<c:url value="/management/controllers.do?category=inactive"/>'>Neaktivní</a>
                            </c:when>
                            <c:when test='${controllersData.filter.category=="inactive"}'>
                                <a href='<c:url value="/management/controllers.do?category=all"/>'>Vše</a>
                                <span>|</span>
                                <a href='<c:url value="/management/controllers.do?category=active"/>'>Aktivní</a>
                                <span>|</span>
                                <strong>Neaktivní</strong>
                            </c:when>
                            <c:otherwise>
                                <a href='<c:url value="/management/controllers.do?category=all"/>'>Vše</a>
                                <span>|</span>
                                <a href='<c:url value="/management/controllers.do?category=active"/>'>Aktivní</a>
                                <span>|</span>
                                <a href='<c:url value="/management/controllers.do?category=inactive"/>'>Neaktivní</a>
                            </c:otherwise>
                        </c:choose>
                    </div>
                    
                </form:form>
                
                <div id="clear">&nbsp;</div>
                
                <c:choose>
                    <c:when test="${controllersData.result.hasData}">
                    
                        <table id="grid">
                            <thead>
                                <tr>
                                    <c:forEach var="orderKey" items="${orderKeys}">
                                        <c:choose>
                                            <c:when test="${!pager.sortable[orderKey]}">
                                                <td>
                                                    <spring:message code="management.controllers.table.${orderKey}"/>
                                                </td>
                                            </c:when>
                                            <c:when test="${pager.displayOrderedBy[orderKey] == null}">
                                                <td><a href="<c:url value="?order=${orderKey}"/>">
                                                        <spring:message code="management.controllers.table.${orderKey}"/>
                                                </a></td>
                                            </c:when>
                                            <c:when test="${pager.displayOrderedBy[orderKey]}">
                                                <td><a class="up" href="<c:url value="?order=${orderKey}.desc"/>">
                                                        <spring:message code="management.controllers.table.${orderKey}"/>
                                                </a></td>
                                            </c:when>
                                            <c:otherwise>
                                                <td><a class="down" href="<c:url value="?order=${orderKey}"/>">
                                                        <spring:message code="management.controllers.table.${orderKey}"/>
                                                </a></td>
                                            </c:otherwise>
                                        </c:choose>
                                    </c:forEach>
                                </tr>
                            </thead>
                            
                            <c:forEach var="controller" items="${controllersData.result.data}" varStatus="status">
                                <c:choose>
                                    <c:when test='${(status.index)%2 eq 0}'>                                
                                        <tr>
                                    </c:when>
                                    <c:otherwise>
                                        <tr class="even">
                                        </c:otherwise>
                                    </c:choose>
                                    <th>${controller.phoneNumber}</th>
                                    <td class="red"><a href="<c:url value="/management/editcontroller.do?id=${controller.id}"/>">${controller.fullName}</a></td>
                                    <c:choose>
                                        <c:when test="${controller.devices[0]!=null}">
                                            <td>
                                                <c:choose>
                                                    <c:when test="${operatorUserPrincipal.operator.type=='OPERATOR'}">
                                                        <a href="<c:url value="/management/editdevice.do?id=${controller.devices[0].id}"/>">${controller.devices[0].name}</a>
                                                    </c:when>
                                                    <c:otherwise>
                                                    ${controller.devices[0].name}
                                                    </c:otherwise>
                                                </c:choose>
                                            </td>
                                        </c:when>
                                        <c:otherwise>
                                            <td>&nbsp;</td>
                                        </c:otherwise>
                                    </c:choose>
                                    <td>${controller.code}</td>
                                    <td>
                                        <c:choose>
                                            <c:when test="${controller.active}">
                                                <spring:message code="management.controllers.active"/>
                                            </c:when>
                                            <c:otherwise>
                                                <spring:message code="management.controllers.inactive"/>
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
                <c:if test="${operatorUserPrincipal.operator.type=='OPERATOR'}">
                    <div id="fhledat">
                        <a href="<c:url value="/management/addcontroller.do"/>"><spring:message code="management.controllers.addNewController"/></a>
                    </div>
                </c:if>
                
            </div>
        </div>
    </body>
</html>