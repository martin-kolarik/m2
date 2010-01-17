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
                        <li><a href="timeload.do" class="b4act">Přehled</a></li>
                        <li><a href="ticketreport.do" class="act">Jízdenky</a></li>
                        <li><a href="controllers.do">Revizoři</a></li>
                        <li><a href="devices.do">MDA zařízení</a></li>
                    </ul>
                </div>
            </div>
            <div id="content">
                <h1><spring:message code="management.ticketreport.title"/></h1>
                <h3>&gt; ${ticketReportData.currentDisplayPeriod}</h3>
                <form:form modelAttribute="ticketReportData">
                
                    <div class="error-list">
                        <form:errors cssClass="errors"/>
                    </div>
                    
                    <div class="filter">
                        <form:radiobutton path="range" value="D" id="day"/>
                        <label for="day"><spring:message code="management.ticketreport.day"/></label>
                        <form:input path="dayString" cssClass="tinput" onchange="document.getElementById('day').checked = true"/>
                        <form:errors cssClass="errors" path="dayString"/>
                        
                        <form:radiobutton path="range" value="W" id="week"/>
                        <label for="week"><spring:message code="management.ticketreport.week"/></label>
                        <form:select path="weekString" items="${weekList}" onchange="document.getElementById('week').checked = true"/>
                        <form:errors cssClass="errors" path="weekString"/>
                        
                        <form:radiobutton path="range" value="M" id="month"/>
                        <label for="month"><spring:message code="management.ticketreport.month"/></label>
                        <form:select path="monthString" items="${monthList}" onchange="document.getElementById('month').checked = true"/>
                        <form:errors cssClass="errors" path="monthString"/>
                    </div>
                    
                    <div class="gfilter">
                        <label for="fword"><spring:message code="management.ticketreport.filterWords"/></label>
                        <form:input path="filterWords" cssClass="input" id="fword"/> 
                        <form:errors cssClass="errors" path="filterWords"/>
                        <input type="submit" id="fhledat" value='<spring:message code="management.ticketreport.submit"/>'/>
                    </div>
                    
                    
                    <div id="listtype">
                        <c:choose>
                            <c:when test='${ticketReportData.filter.category=="all"}'>
                                <strong>Vše</strong>
                                <span>|</span>
                                <a href='<c:url value="/management/ticketreport.do?category=not_processed"/>'>Nezpracováno</a>
                                <span>|</span>
                                <a href='<c:url value="/management/ticketreport.do?category=sent"/>'>Odesláno</a>
                            </c:when>
                            <c:when test='${ticketReportData.filter.category=="not_processed"}'>
                                <a href='<c:url value="/management/ticketreport.do?category=all"/>'>Vše</a>
                                <span>|</span>
                                <strong>Nezpracováno</strong>
                                <span>|</span>
                                <a href='<c:url value="/management/ticketreport.do?category=sent"/>'>Odesláno</a>
                            </c:when>
                            <c:when test='${ticketReportData.filter.category=="sent"}'>
                                <a href='<c:url value="/management/ticketreport.do?category=all"/>'>Vše</a>
                                <span>|</span>
                                <a href='<c:url value="/management/ticketreport.do?category=not_processed"/>'>Nezpracováno</a>
                                <span>|</span>
                                <strong>Odesláno</strong>
                            </c:when>
                            <c:otherwise>
                                <a href='<c:url value="/management/ticketreport.do?category=all"/>'>Vše</a>
                                <span>|</span>
                                <a href='<c:url value="/management/ticketreport.do?category=not_processed"/>'>Nezpracováno</a>
                                <span>|</span>
                                <a href='<c:url value="/management/ticketreport.do?category=sent"/>'>Odesláno</a>
                            </c:otherwise>
                        </c:choose>
                    </div>
                    
                </form:form>
                <div id="clear">&nbsp;</div>
                
                <c:choose>
                    <c:when test="${ticketReportData.result.hasData}">
                    
                        <table id="grid">
                            <thead>
                                <tr>
                                    <c:forEach var="orderKey" items="${orderKeys}">
                                        <c:choose>
                                            <c:when test="${!pager.sortable[orderKey]}">
                                                <td>
                                                    <spring:message code="management.ticketreport.table.${orderKey}"/>
                                                </td>
                                            </c:when>
                                            <c:when test="${pager.displayOrderedBy[orderKey] == null}">
                                                <td><a href="<c:url value="?order=${orderKey}"/>">
                                                        <spring:message code="management.ticketreport.table.${orderKey}"/>
                                                </a></td>
                                            </c:when>
                                            <c:when test="${pager.displayOrderedBy[orderKey]}">
                                                <td><a class="up" href="<c:url value="?order=${orderKey}.desc"/>">
                                                        <spring:message code="management.ticketreport.table.${orderKey}"/>
                                                </a></td>
                                            </c:when>
                                            <c:otherwise>
                                                <td><a class="down" href="<c:url value="?order=${orderKey}"/>">
                                                        <spring:message code="management.ticketreport.table.${orderKey}"/>
                                                </a></td>
                                            </c:otherwise>
                                        </c:choose>
                                    </c:forEach>
                                </tr>
                            </thead>
                            
                            <c:forEach var="ticket" items="${ticketReportData.result.data}" varStatus="status">
                                <c:choose>
                                    <c:when test='${(status.index)%2 eq 0}'>                                
                                        <tr>
                                    </c:when>
                                    <c:otherwise>
                                        <tr class="even">
                                        </c:otherwise>
                                    </c:choose>
                                    <th>${ticket.ticketId}</th>
                                    <td>${ticket.validFrom}</td>
                                    <td>${ticket.validTo}</td>
                                    <td class="p15 red"><a href="<c:url value="/management/ticketdetail.do?id=${ticket.id}"/>">${ticket.phoneNumber}</a></td>
                                    <td>${ticket.incomingSms.operator}</td>
                                    <td>${ticket.hash}</td>
                                    <td>${ticket.code}</td>
                                    <td class="p20"><spring:message code="management.ticketreport.category.${ticket.outgoingSms.state}"/></td>
                                </tr>
                            </c:forEach>
                        </table>
                        
                        <p><%@include file="/WEB-INF/jsp/includes/pager.jsf"%></p>
                        
                        <c:if test="${operatorUserPrincipal.operator.type=='OPERATOR'}">
                            <form:form action="csvexport.do">
                                <input type="submit" id="fhledat" value='<spring:message code="management.csvexport.submit"/>'/>
                            </form:form>
                        </c:if>
                        
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