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
                <h1><spring:message code="management.controllerchecks.title"/> &#151;
                    ${controllerChecksData.controller.firstName}
                    ${controllerChecksData.controller.lastName}
                (${controllerChecksData.controller.code})</h1>
                <h3>&gt; ${controllerChecksData.currentDisplayPeriod}</h3>

                <div id="clear">&nbsp;</div>

                <div class="frame">
                    <a class="close" href='<c:url value="/management/controllers.do"/>'><spring:message code="management.ticketdetail.close"/></a>
                    <a href="<c:url value="/management/editcontroller.do?id=${controllerChecksData.controller.id}"/>"><spring:message code="management.controllerchecks.detail"/></a>
                    <span>|</span>
                    <strong><spring:message code="management.controllerdetail.checks"/></strong>
                </div>                
                                
                <form:form modelAttribute="controllerChecksData">
                
                    <div class="filter">
                        <div class="error-list">
                            <form:errors cssClass="errors"/>
                        </div>
                        
                        <form:radiobutton path="range" value="D" id="day"/>
                        <label for="day"><spring:message code="management.controllerchecks.day"/></label>
                        <form:input path="dayString" cssClass="tinput" onchange="document.getElementById('day').checked = true"/>
                        <form:errors cssClass="errors" path="dayString"/>
                        
                        <form:radiobutton path="range" value="W" id="week"/>
                        <label for="week"><spring:message code="management.controllerchecks.week"/></label>
                        <form:select path="weekString" items="${weekList}" onchange="document.getElementById('week').checked = true"/>
                        <form:errors cssClass="errors" path="weekString"/>
                        
                        <form:radiobutton path="range" value="M" id="month"/>
                        <label for="month"><spring:message code="management.controllerchecks.month"/></label>
                        <form:select path="monthString" items="${monthList}" onchange="document.getElementById('month').checked = true"/>
                        <form:errors cssClass="errors" path="monthString"/>
                    </div>
                    
                    <div class="filter">
                        <form:radiobutton path="range" value="F" id="from"/>
                        <label for="from"><spring:message code="management.controllerchecks.dateFrom"/></label>
                        <form:input path="dateFromString" cssClass="tinput" onchange="document.getElementById('from').checked = true"/>
                        <form:errors cssClass="errors" path="dateFromString"/>
                        
                        <label for="to"><spring:message code="management.controllerchecks.dateTo"/></label>
                        <form:input path="dateToString" cssClass="tinput" onchange="document.getElementById('from').checked = true"/>
                        <form:errors cssClass="errors" path="dateToString"/>
                        
                        <input type="submit" id="fhledat" value='<spring:message code="management.controllerchecks.submit"/>'/>
                    </div>
                </form:form>
                
                <div id="clear">&nbsp;</div>
                
                <c:choose>
                    <c:when test="${controllerChecksData.result.hasData}">
                    
                        <table id="grid">
                            <thead>
                                <tr>
                                    <c:forEach var="orderKey" items="${orderKeys}">
                                        <c:choose>
                                            <c:when test="${!pager.sortable[orderKey]}">
                                                <td>
                                                    <spring:message code="management.controllerchecks.table.${orderKey}"/>
                                                </td>
                                            </c:when>
                                            <c:when test="${pager.displayOrderedBy[orderKey] == null}">
                                                <td><a href="<c:url value="?order=${orderKey}"/>">
                                                        <spring:message code="management.controllerchecks.table.${orderKey}"/>
                                                </a></td>
                                            </c:when>
                                            <c:when test="${pager.displayOrderedBy[orderKey]}">
                                                <td><a class="up" href="<c:url value="?order=${orderKey}.desc"/>">
                                                        <spring:message code="management.controllerchecks.table.${orderKey}"/>
                                                </a></td>
                                            </c:when>
                                            <c:otherwise>
                                                <td><a class="down" href="<c:url value="?order=${orderKey}"/>">
                                                        <spring:message code="management.controllerchecks.table.${orderKey}"/>
                                                </a></td>
                                            </c:otherwise>
                                        </c:choose>
                                    </c:forEach>
                                </tr>
                            </thead>
                            
                            <c:forEach var="check" items="${controllerChecksData.result.data}" varStatus="status">
                                <c:choose>
                                    <c:when test='${(status.index)%2 eq 0}'>                                
                                        <tr>
                                    </c:when>
                                    <c:otherwise>
                                        <tr class="even">
                                        </c:otherwise>
                                    </c:choose>
                                    <td><fmt:formatDate value="${check.createdSort}" pattern="dd.MM.yyyy HH:mm:ss"/></td>
                                    <c:choose>
                                        <c:when test='${empty check.ticket.phoneNumber}'>                                
                                            <td></td>
                                        </c:when>
                                        <c:otherwise>
                                            <td>${check.ticket.phoneNumber}/${check.ticket.hash}</td>
                                        </c:otherwise>
                                    </c:choose>
                                    <td><spring:message code="management.controllerchecks.status.${check.status}"/></td>
                                    <td>${check.controllerSms.text}</td>
                                    <td>${check.customerSms.text}</td>
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
                
                <div class="frame">
                    <a class="close" href='<c:url value="/management/controllers.do"/>'><spring:message code="management.ticketdetail.close"/></a>
                    <a href="<c:url value="/management/editcontroller.do?id=${controllerChecksData.controller.id}"/>"><spring:message code="management.controllerchecks.detail"/></a>
                    <span>|</span>
                    <strong><spring:message code="management.controllerdetail.checks"/></strong>
                </div>                
                                                               
            </div>
        </div>
    </body>
</html>