<%@page contentType="text/html" pageEncoding="UTF-8"%><%@
include file="/WEB-INF/jsp/includes/include.jspf"
        %><!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
    <head>
        <meta http-equiv="Content-Type" content="text/html; charset=UTF-8" />
        <title>ÚČTENKA - Daňový doklad</title>
        <link rel="stylesheet" type="text/css" href='<c:url value="/css/doklad.css"/>' />
    </head>
    <body>
        <div>
            <span>
                <a href="#" id="print" onclick="window.print();">Tisk</a>
                <a href="#" id="close" onclick='window.location.href="bills.do";'>Zavřít</a>
            </span>
        </div>
        <table>
            <tr id="fst">
                <td>Odběratel:<br />DIČ:</td>
                <td colspan="2" class="right"><strong>ÚČTENKA - Daňový doklad</strong><br />č.: <c:out value="${bill.billNumber}"/></td>
            </tr>
            <tr id="snd">
                <td>Předmět</td>
                <td>Cena za MJ</td>
                <td>Cena celkem</td>
            </tr>
            <tr id="trd">
                <td>Elektronická jízdenka</td>
                <td>&nbsp;</td>
                <td>&nbsp;</td>
            </tr>
            <tr class="item">
                <td><c:out value='${bill.tickets[0].ticketType.name}'/>: <c:out value="${ticketCount}"/> ks<br />
                <c:forEach items="${bill.tickets}" var="ticket">
                    <small><c:out value='${ticket.phoneNumber}'/> (<fmt:formatDate value="${ticket.validFrom}" pattern="d.M.yy H:mm"/> - <fmt:formatDate value="${ticket.validTo}" pattern="d.M.yy H:mm"/>)</small><br/>
                </c:forEach>                 
                <td class="center"><c:out value='${bill.tickets[0].price}'/> Kč</td>
                <td class="center"><c:out value='${bill.price}'/> Kč</td>
            </tr>
            <tr id="fifth">
                <td id="c1">Datum uskuteč. zdanit. plnění: <fmt:formatDate value="${bill.taxDate}" pattern="d.M.yyyy"/><br />Cena je vč. <c:out value='${bill.vatRate}'/>% sazby DPH</td>
                <td id="c2"><span>Uhrazeno</span></td>
                <td id="c3"><span><c:out value='${bill.price}'/> Kč</span></td>
            </tr>
            <tr id="last">
                <td colspan="3">
                    <em>Dodavatel:</em>
                    <c:out value='${bill.companyName}'/><br />
                    <c:out value='${bill.companyStreet}'/><br />
                    <c:out value='${bill.companyPostcode}'/> <c:out value='${bill.companyCity}'/><br />
                    IČ: <c:out value='${bill.companyIco}'/><br />
                    DIČ: <c:out value='${bill.companyDic}'/>
                </td>
            </tr>
        </table>
    </body>
</html>
