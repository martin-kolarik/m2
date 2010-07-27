/*
 * To change this template, choose Tools | Templates
 * and open the template in the editor.
 */

package cz.smartcontrol.web.servlet.tags.pager;

import cz.smartcontrol.query.Pager;
import javax.servlet.jsp.JspTagException;
import javax.servlet.jsp.tagext.TagSupport;

/**
 *
 * @author Martin
 */
public class Common extends TagSupport {
    
//-----------------------------------------------------------------------------

    private String pagerTagId;
    private PagerTag pagerTag;
    
    private Pager pager;

    public void setPager( String pagerTagId ) { // setter for attribute "pager"
        this.pagerTagId = pagerTagId;
    }
    
    protected Pager getPager() {
        return pager;
    }

//-----------------------------------------------------------------------------

    protected void lookupOwner() throws JspTagException {
        
        if( pagerTagId == null ) {
            pagerTag = (PagerTag)findAncestorWithClass( this, PagerTag.class );
            if( pagerTag == null ) {
                throw new JspTagException( "Owning pager tag not found, place tag inside pager tag or define pager attribute" );
            }

        } else { // use explicit linkning
            pagerTag = (PagerTag)pageContext.getAttribute( pagerTagId );
            if( pagerTag == null ) {
                throw new JspTagException( "Pager tag with id " + pagerTagId + " not found" );
            }
        }
        
        pager = pagerTag.getPager();
    }

//-----------------------------------------------------------------------------

    protected String getUri( int page ) {
        return pagerTag.getUrl() + "?" + pagerTag.getParameter() + "=" + Integer.toString( page );
    }
    
//-----------------------------------------------------------------------------

}
