package cz.smartcontrol.licensing.web.controllers.management;

import cz.smartcontrol.licensing.business.facade.LicenceFacade;
import cz.smartcontrol.licensing.business.facade.ManufacturerFacade;
import cz.smartcontrol.licensing.business.facade.ProductFacade;
import cz.smartcontrol.query.Result;
import cz.smartcontrol.licensing.web.commands.ProductsVersionCommand;
import cz.smartcontrol.licensing.web.session.ProductsVersionBacking;
import cz.smartcontrol.licensing.web.session.TimeFilterBacking;
import cz.smartcontrol.licensing.web.validation.ControllerChecksValidator;
import javax.servlet.http.HttpSession;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.ui.Model;
import org.springframework.validation.Errors;
import org.springframework.web.bind.annotation.ModelAttribute;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestMethod;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.SessionAttributes;

//--------------------------------------------------------------------------------

/**
 *
 * @author strzinek
 */
@org.springframework.stereotype.Controller
@SessionAttributes( ProductVersions.NAME_CHECKS_DATA  )
public class ProductVersions implements OperatorSecuredArea {
    
    public static final String NAME_CHECKS_DATA = "productVersionsData";

    @Autowired
    LicenceFacade licenceLogic;
    
    @Autowired
    ProductFacade productLogic;
    
    @Autowired
    ManufacturerFacade manufacturerLogic;
    
//================================================================================

    @RequestMapping( value = "/management/controllerchecks.do", method = RequestMethod.GET )
    public String setupReport(
            HttpSession session, Model model,
            @RequestParam( value = "id", required = false ) String controllerId,
            @RequestParam( value = "items", required = false ) String pageSizeIncrement,
            @RequestParam( value = "page", required = false ) String page,
            @RequestParam( value = "order", required = false ) String orderBy ) throws Exception {

        // prepare backing
        ProductsVersionBacking backing = ProductsVersionBacking.getInstance( session );
        ProductsVersionCommand command = backing.getProductVersionsCommand();
        
        if( controllerId != null ) {
            // if ( ProductsVersionBacking.getInstance( session ).allowedController( controllerId )) {
            //     command.setController( controllerLogic.getController( new Long( controllerId )).toExport( false, false ));
            // } else {
            //     throw new Exception( "Unknown controller" );
            // }
        // } else if( command.getController() == null ) {
            // throw new Exception( "Unknown controller" );
        }

        // apply paging and ordering
        backing.getPager().updateByWebRequest( pageSizeIncrement, page, orderBy );

        // do action
        command.setupFilter();
        // command.getFilter().setControllerId( command.getController().getRawId());
        // Result result = checkLogic.getChecks( command.getFilter(), backing.getPager());
        // command.setResult( result );

        // prepare models
        backing.bindToModel( model );
        model.addAttribute( NAME_CHECKS_DATA, command );
        TimeFilterBacking.getInstance( session, licenceLogic ).bindToModel( model );
        model.addAttribute( OperatorUserPrincipal.SESSION_NAME, session.getAttribute(OperatorUserPrincipal.SESSION_NAME));

        return "management/controllerchecks";
    }
    
//--------------------------------------------------------------------------------

    @RequestMapping( value = "/management/controllerchecks.do", method = RequestMethod.POST )
    public String processReport(
            HttpSession session, Model model,
            @ModelAttribute( NAME_CHECKS_DATA ) ProductsVersionCommand command, Errors errors ) throws Exception {

        ProductsVersionBacking backing = ProductsVersionBacking.getInstance( session );

        // validate
        new ControllerChecksValidator().validate(command, errors);
        if( errors.hasErrors()) {
            backing.bindToModel( model );
            model.addAttribute( NAME_CHECKS_DATA, command );
            return "management/controllerchecks";
        }
        
        // do action
        backing.getPager().setDisplayPage( 1 ); // reset paging when changing filter (POST request)
        backing.getProductVersionsCommand().setupFilter();
        // Result result = checkLogic.getChecks( command.getFilter(), backing.getPager());
        // backing.getProductVersionsCommand().setResult( result );

        // prepare models
        backing.bindToModel( model );
        model.addAttribute( NAME_CHECKS_DATA, command );
        TimeFilterBacking.getInstance( session, licenceLogic ).bindToModel( model );
        model.addAttribute( OperatorUserPrincipal.SESSION_NAME, session.getAttribute(OperatorUserPrincipal.SESSION_NAME));

        return "management/controllerchecks";
    }
    
//================================================================================

}
