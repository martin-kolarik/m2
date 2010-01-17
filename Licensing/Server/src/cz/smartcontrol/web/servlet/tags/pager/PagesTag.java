/*
 * To change this template, choose Tools | Templates
 * and open the template in the editor.
 */

package cz.smartcontrol.web.servlet.tags.pager;

import javax.servlet.jsp.JspTagException;

/**
 *
 * @author Martin
 */
public class PagesTag extends Common {

//-----------------------------------------------------------------------------

    private String uriId;
    
    private String iteratePageNumberId;
    
    private String pageNumberId;
    
    private String activeId;
    
    private Integer range = new Integer( 10 );
    
    private int iteratePage;
    
    private int lastIteratePage;
    
    public void setUriId( String uriId ) {
        this.uriId = uriId;
    }

    public void setIteratePageNumberId( String iteratePageNumberId ) {
        this.iteratePageNumberId = iteratePageNumberId;
    }

    public void setPageNumberId( String pageNumberId ) {
        this.pageNumberId = pageNumberId;
    }
    
    public void setActiveId( String activeId ) {
        this.activeId = activeId;
    }
    
    public void setRange( Integer range ) {
        this.range = range;
    }

//-----------------------------------------------------------------------------

    @Override
    public int doStartTag() throws JspTagException {
        
        lookupOwner();
        
        int currentPage = getPager().getDisplayPage();
        int pages = getPager().getPages();
        int firstPage = currentPage - range / 2 + 1;
        int lastPage = currentPage + range / 2;
        // correct right bound: even if last page is selected the pager must show all range items...
        if( lastPage > pages ) {
            firstPage = firstPage - lastPage + pages;
            lastPage = pages;
        }
        if( firstPage < 1 ) { // ...but not negative
            lastPage = lastPage - firstPage + 1;
            firstPage = 1;
        }
        if( lastPage > pages ) { // ...and again not over range
            lastPage = pages;
        }
        
        if( pageNumberId != null ) {
            pageContext.setAttribute( pageNumberId, new Integer( currentPage ));
        }

        iteratePage = firstPage;
        lastIteratePage = lastPage;
        
        if( iteratePage <= lastIteratePage ) {
            setupExportedVariables();
            return EVAL_BODY_INCLUDE;

        } else {
            return SKIP_BODY;
        }
    }

//-----------------------------------------------------------------------------

    @Override
    public int doAfterBody() throws JspTagException {
        
        if( iteratePage < lastIteratePage ) {
            iteratePage = iteratePage + 1;
            setupExportedVariables();
            return EVAL_BODY_AGAIN;

        } else {
            return SKIP_BODY;
        }
    }
    
//-----------------------------------------------------------------------------

    @Override
    public int doEndTag() throws JspTagException {

        if( uriId != null ) {
            pageContext.setAttribute( uriId, null );
        }
        if( iteratePageNumberId != null ) {
            pageContext.setAttribute( iteratePageNumberId, null );
        }
        if( pageNumberId != null ) {
            pageContext.setAttribute( pageNumberId, null );
        }
        
        return EVAL_PAGE;
    }

//-----------------------------------------------------------------------------

    public void setupExportedVariables() {

        if( uriId != null ) {
            pageContext.setAttribute( uriId, getUri( iteratePage ));
        }
        if( iteratePageNumberId != null ) {
            pageContext.setAttribute( iteratePageNumberId, new Integer( iteratePage ));
        }
        if( activeId != null ) {
            pageContext.setAttribute( activeId, new Boolean( iteratePage == getPager().getDisplayPage()));
        }
    }
        
//-----------------------------------------------------------------------------

}
