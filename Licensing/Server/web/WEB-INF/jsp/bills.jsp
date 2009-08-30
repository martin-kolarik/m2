<%@page contentType="text/html" pageEncoding="UTF-8"%><%@
include file="/WEB-INF/jsp/includes/include.jspf"
        %><!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
    <head>
        <meta http-equiv="Content-Type" content="text/html; charset=UTF-8" />
        <title><spring:message code="smstickets.title"/></title>
        <link rel="stylesheet" href='<c:url value="/css/style.css"/>' type="text/css"/>
        <link rel="icon" href='<c:url value="/favicon.ico"/>' type="image/x-icon"/>
    </head>
    <body>
        <div id="holder2">
            <div id="top2">
                <a href="/" id="sms">SMS Jízdenka<span></span></a>
                <a href="ˇhttp://www.dpmul.cz/" id="dpmul">Dopravní podnik<br /> města Ústí nad Labem a.s.</a>
            </div>
            <div id="content2">
                
                <div class="fl links">
                    <a href="<c:url value="/tickets.do"/>"><spring:message code="public.bills.ticketsLink"/></a> |
                    <a class="act" href="<c:url value="/bills.do"/>" ><spring:message code="public.bills.billsLink"/></a>
                    <c:if test="${customer.parentCustomer==null}">
                        | <a href="<c:url value="/customers.do"/>" ><spring:message code="public.bills.childsLink"/></a>
                    </c:if>
                </div>
                
                <div class="fr user">
                    <spring:message code="public.bills.loginUserPhoneNumber"/>
                    <strong><c:out value="${customer.phoneNumber}"/></strong> |
                    <a href="<c:url value="/logout.do"/>"><spring:message code="logout"/></a>
                </div>
                
                <form:form id="filter" modelAttribute="billsData">
                
                    <div class="fr">
                        <label for="year"><spring:message code="public.tickets.year"/></label>
                        <form:select path="yearString" items="${yearList}" id="year"/>
                        <form:errors cssClass="errors" path="yearString"/>
                        
                        <input type="submit" value='<spring:message code="public.tickets.filter"/>' class="button"/>
                    </div>
                </form:form>
                
                <c:choose>
                    <c:when test="${billsData.result.hasData}">
                    
                        <table id="list">
                            <thead>
                                <tr>
                                    <th>&nbsp;</th>
                                    <c:forEach var="orderKey" items="${orderKeys}">
                                        <c:choose>
                                            <c:when test="${!pager.sortable[orderKey]}">
                                                <th>
                                                    <spring:message code="public.bills.table.${orderKey}"/>
                                                </th>
                                            </c:when>
                                            <c:when test="${pager.displayOrderedBy[orderKey] == null}">
                                                <th><a href="<c:url value="?order=${orderKey}"/>">
                                                        <spring:message code="public.bills.table.${orderKey}"/>
                                                </a></th>
                                            </c:when>
                                            <c:when test="${pager.displayOrderedBy[orderKey]}">
                                                <th><a class="up" href="<c:url value="?order=${orderKey}.desc"/>">
                                                        <spring:message code="public.bills.table.${orderKey}"/>
                                                </a></th>
                                            </c:when>
                                            <c:otherwise>
                                                <th><a class="down" href="<c:url value="?order=${orderKey}"/>">
                                                        <spring:message code="public.bills.table.${orderKey}"/>
                                                </a></th>
                                            </c:otherwise>
                                        </c:choose>
                                    </c:forEach>
                                    <th>&nbsp;</th>
                                </tr>
                            </thead>
                            
                            <c:forEach var="bill" items="${billsData.result.data}" varStatus="status">
                                <c:choose>
                                    <c:when test='${(status.index)%2 eq 0}'>                                
                                        <tr>
                                    </c:when>
                                    <c:otherwise>
                                        <tr class="even">
                                        </c:otherwise>
                                    </c:choose>
                                    <td>&nbsp;</td>                                
                                    <td>${bill.billNumber}</td>
                                    <td><fmt:formatDate value="${bill.taxDate}" pattern="d. M. yyyy"/></td>
                                    <td>${bill.vatRate}</td>
                                    <td>${bill.price} Kč</td>
                                    <td>
                                        <a href="<c:url value="/bill.do?id="/><c:out value="${bill.billId}"/>" class="print"><spring:message code="public.bills.bill"/></a>
                                    </td>
                                    <td>&nbsp;</td>                                
                                </tr>
                            </c:forEach>
                        </table>
                        
                        <%@include file="/WEB-INF/jsp/includes/pager_client.jsf"%>
                        
                    </c:when>
                    <c:otherwise>
                        <p>
                            <spring:message code="public.bills.nodata"/>
                        </p>
                    </c:otherwise>
                </c:choose>
                
                <div id="linka">&nbsp;</div>
                
                <div id="text">
                    <h1>Nápověda</h1>
                    
                    <h2>Navigace</h2>
                    <p>V horní části stránky je menu o třech položkách.</p>
                    <ul>
                        <li>Jízdenky</li>
                        <li>Účtenky</li>
                        <li>Telefonní čísla</li>
                    </ul>
                    <p>Poklikem se zobrazí seznam jízdenek nebo vystavených účtenek.</p>
                    
                    <h2>Jízdenky</h2>
                    <p>Zobrazen seznam vystavených jízdenek na přihlášeného uživatele (cestujícího) resp.
                    jeho telefonní číslo.</p>
                    
                    <h2>Vystavení jednotlivé účtenky</h2>
                    <p>Vystavení jednotlivých daňových dokladů provedete stiskem tlačítka TISK u každého zobrazeného řádku.
                        Vystavený doklad se zobrazí v novém okně, kde si ho můžete vytisknout a zároveň se účtenka uloží
                    do seznamu ÚČTENKY. Jízdenka, na kterou byla vystavena účtenka, nelze vyúčtovat vícekrát.</p>
                    
                    <h2>Vystavení účtenky s více jízdenkami</h2>						
                    <p>Vystavení účtenky s více jízdenkami provedete pomocí zaškrtávacího pole na začátku kažkého řádku.
                        Po výběru se v levém horním rohu seznamu jízdenek zobrazí tlačítko TISK. Po stisknutí se vystavený doklad 
                        zobrazí v novém okně, kde si ho můžete vytisknout a zároveň se účtenka uloží
                    do seznamu ÚČTENKY. Jízdenky vybrané na této účtence jsou ze seznamu jízdenek smazány.</p>
                    
                    <h2>Přiřazení telefonních čísel</h2>						
                    <p>K Vašemu telefonnímu číslu je možné přiřadit další telefonní čísla. V seznamu jízdenek je potom možné zobrazovat jízdenky 
                    všech přiřazených telefonních čísel a vystavovat k nim účtenky.</p>
                </div><!-- help text -->

            </div><!-- content -->
        </div><!-- holder -->

        <div id="footer">
            <spring:message code="copyright"/>
        </div>
    </body>
</html>
