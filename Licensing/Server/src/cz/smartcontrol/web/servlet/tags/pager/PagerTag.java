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
public class PagerTag extends TagSupport {
    
//-----------------------------------------------------------------------------

    private Pager pager;

    public Pager getPager() {
        return pager;
    }

    public void setPager( Pager pager ) {
        this.pager = pager;
    }

//-----------------------------------------------------------------------------
    
    private static final String DEFAULT_PARAMETER_NAME = "page";

    private String parameter = DEFAULT_PARAMETER_NAME;
    private String url;
    
    public String getParameter() {
        return parameter;
    }

    public void setUrl( String url ) {
        this.url = url;
    }

    public String getUrl() {
        return url;
    }

//-----------------------------------------------------------------------------

    @Override
    public int doStartTag() throws JspTagException {
        
        if( pager == null ) {
            throw new JspTagException( "Pager attribute not set" );
        } else if( !Pager.class.isInstance( pager )) {
            throw new JspTagException( "Pager attribute is not " + Pager.class.getName());
        }
        if( url == null ) {
            throw new JspTagException( "Url attribute not set" );
        }
        
        if( getId() != null ) {
            pageContext.setAttribute( getId(), this );
        }

        return EVAL_BODY_INCLUDE;
    }

//-----------------------------------------------------------------------------

}
