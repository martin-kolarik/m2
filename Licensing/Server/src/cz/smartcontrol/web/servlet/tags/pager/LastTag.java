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
public class LastTag extends Common {

//-----------------------------------------------------------------------------

    private String uriId;
    
    private String pageNumberId;
    
    private String activeId;
    
    public void setUriId( String uriId ) {
        this.uriId = uriId;
    }

    public void setPageNumberId( String pageNumberId ) {
        this.pageNumberId = pageNumberId;
    }
    
    public void setActiveId( String activeId ) {
        this.activeId = activeId;
    }

//-----------------------------------------------------------------------------

    @Override
    public int doStartTag() throws JspTagException {
        
        lookupOwner();
        
        int pages = getPager().getPages();
        if( uriId != null ) {
            pageContext.setAttribute( uriId, getUri( pages ));
        }
        if( pageNumberId != null ) {
            pageContext.setAttribute( pageNumberId, new Integer( pages ));
        }
        if( activeId != null ) {
            pageContext.setAttribute( activeId, new Boolean( getPager().getDisplayPage() < pages ));
        }
        
        return EVAL_BODY_INCLUDE;
    }

//-----------------------------------------------------------------------------

    @Override
    public int doEndTag() throws JspTagException {

        if( uriId != null ) {
            pageContext.setAttribute( uriId, null );
        }
        if( pageNumberId != null ) {
            pageContext.setAttribute( pageNumberId, null );
        }
        if( activeId != null ) {
            pageContext.setAttribute( activeId, null );
        }
        
        return EVAL_PAGE;
    }

//-----------------------------------------------------------------------------

}
