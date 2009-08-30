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
                <h1><spring:message code="management.ticketdetail.title"/> ${ticket.phoneNumber} / ${ticket.hash}</h1>
                <div class="frame">
                    <a class="close" href='<c:url value="/management/ticketreport.do"/>'><spring:message code="management.ticketdetail.close"/></a>
                    <strong>Detail</strong>
                    
                </div>
                <h2>Základní informace</h2>
                <table id="ticketinfo">
                    <tr>
                        <th><spring:message code="management.ticketdetail.id"/></th>
                        <td>${ticket.ticketId}</td>
                    </tr>
                    <tr class="even">
                        <th><spring:message code="management.ticketdetail.state"/></th>
                        <td><spring:message code="management.ticketdetail.state.${ticket.outgoingSms.state}"/></td>
                    </tr>
                    <tr>
                        
                        <th><spring:message code="management.ticketdetail.validity"/></th>
                        <td>${ticket.validFrom} -- ${ticket.validTo}</td>
                    </tr>
                    <tr class="even">
                        <th><spring:message code="management.ticketdetail.number"/></th>
                        <td>${ticket.phoneNumber}</td>
                    </tr>
                    <tr>
                        <th><spring:message code="management.ticketdetail.operator"/></th>
                        <td>${ticket.incomingSms.operator}</td>
                    </tr>
                    <tr class="even">
                        <th><spring:message code="management.ticketdetail.hash"/></th>
                        <td>${ticket.hash}</td>
                    </tr>
                    <tr>
                        <th><spring:message code="management.ticketdetail.code"/></th>
                        <td id="kod">${ticket.code}</td>
                        
                    </tr>
                    <tr class="even">
                        <th><spring:message code="management.ticketdetail.type"/></th>
                        <td>${ticket.ticketType.name}</td>
                    </tr>
                    <tr>
                        <th><spring:message code="management.ticketdetail.price"/></th>
                        <td>${ticket.price} CZK</td>
                    </tr>
                </table>
                
                <table id="grid">
                    <thead>
                        <tr>
                            <td><spring:message code="management.ticketdetail.event"/>
                            </td>
                            <td><spring:message code="management.ticketdetail.time"/>
                            </td>
                            <td><spring:message code="management.ticketdetail.smsCodeName"/>
                            </td>
                            <td><spring:message code="management.ticketdetail.smsState"/>
                            </td>
                            <td><spring:message code="management.ticketdetail.smsText"/>
                            </td>
                        </tr>
                    </thead>
                    
                    <c:forEach var="event" items="${events}" varStatus="status">
                        <c:choose>
                            <c:when test='${(status.index)%2 eq 0}'>                                
                                <tr>
                            </c:when>
                            <c:otherwise>
                                <tr class="even">
                                </c:otherwise>
                            </c:choose>
                            <c:choose>
                                <c:when test="${event.isCheck}">
                                    <td><spring:message code="management.ticketdetail.event.${event.type}"/></td>
                                    <td><fmt:formatDate value="${event.sortTime}" pattern="dd.MM.yyyy HH:mm:ss"/></td>
                                    <td>${event.check.text}</td>
                                    <td><spring:message code="management.controllerchecks.status.${event.check.status}"/></td>
                                    <td>${event.check.controllerName}</td>
                                </c:when>
                                <c:when test="${event.isIncomingSms}">
                                    <td><spring:message code="management.ticketdetail.event.${event.type}"/></td>
                                    <td><fmt:formatDate value="${event.incomingSms.sortReceived}" pattern="dd.MM.yyyy HH:mm:ss"/></td>
                                    <td>${event.incomingSms.code}</td>
                                    <td><spring:message code="management.ticketdetail.state.${event.incomingSms.state}"/></td>
                                    <td>${event.incomingSms.text}</td>
                                </c:when>
                                <c:otherwise>
                                    <td><spring:message code="management.ticketdetail.event.${event.type}"/></td>
                                    <td><fmt:formatDate value="${event.outgoingSms.sortSmsSent}" pattern="dd.MM.yyyy HH:mm:ss"/></td>
                                    <td>${event.outgoingSms.code}</td>
                                    <td><spring:message code="management.ticketdetail.state.${event.outgoingSms.state}"/></td>
                                    <td>${event.outgoingSms.text}</td>
                                </c:otherwise>
                            </c:choose>
                        </tr>
                    </c:forEach>
                </table>
                
                <div class="frame">
                    <a class="close" href='<c:url value="/management/ticketreport.do"/>'><spring:message code="management.ticketdetail.close"/></a>
                    <strong>Detail</strong>
                    
                </div>
            </div>
        </div>
    </body>
</html>

