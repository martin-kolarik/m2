package cz.smartcontrol.licensing.web.controllers.management;

import cz.smartcontrol.licensing.business.facade.ManufacturerFacade;
import cz.smartcontrol.query.Result;
import cz.smartcontrol.licensing.domain.Operator;
import cz.smartcontrol.licensing.domain.OperatorType;
import cz.smartcontrol.licensing.web.commands.ManufacturerDetailCommand;
import cz.smartcontrol.licensing.web.commands.ManufacturersCommand;
import cz.smartcontrol.licensing.web.session.ManufacturersBacking;
import cz.smartcontrol.licensing.web.validation.ManufacturerValidator;
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
@SessionAttributes( {Manufacturers.NAME_REPORT_DATA, Manufacturers.NAME_DETAIL_DATA}    )
public class Manufacturers implements OperatorSecuredArea {
    
    public static final String NAME_REPORT_DATA = "controllersData";
    public static final String NAME_DETAIL_DATA = "controller";
    public static final String NAME_COMPANIES = "companies";
    public static final String NAME_CONTROLLER_GROUPS = "controllerGroups";
    
    @Autowired
    ManufacturerFacade manufacturerLogic;
    
//================================================================================

    @RequestMapping( value = "/management/controllers.do", method = RequestMethod.GET )
    public String setupReport(
            HttpSession session, Model model,
            @RequestParam( value = "items", required = false ) String pageSizeIncrement,
            @RequestParam( value = "page", required = false ) String page,
            @RequestParam( value = "order", required = false ) String orderBy ) throws Exception {

        // prepare backing
        ManufacturersBacking backing = ManufacturersBacking.getInstance( session );
        
        // apply paging and ordering
        backing.getPager().updateByWebRequest( pageSizeIncrement, page, orderBy );

        // do action
        ManufacturersCommand command = backing.getManufacturersCommand();
        // apply category to filter

        command.setupFilter();
        Result result = manufacturerLogic.getManufacturers( command.getFilter(), backing.getPager());
        command.setResult( result );
        // backing.createAllowedControllers( result );
        // DevicesBacking.getInstance( session ).createAllowedDevicesFromControllers( result );

        // prepare models
        backing.bindToModel( model );
        model.addAttribute( NAME_REPORT_DATA, command );
        model.addAttribute( OperatorUserPrincipal.SESSION_NAME, session.getAttribute(OperatorUserPrincipal.SESSION_NAME));

        return "management/controllers";
    }
    
//--------------------------------------------------------------------------------

    @RequestMapping( value = "/management/controllers.do", method = RequestMethod.POST )
    public String processReport(
            HttpSession session, Model model,
            @ModelAttribute( NAME_REPORT_DATA ) ManufacturersCommand command ) throws Exception {

        // no validation needed now
        ManufacturersBacking backing = ManufacturersBacking.getInstance( session );
        backing.getPager().setDisplayPage( 1 ); // reset paging when changing filter (POST request)
        backing.getManufacturersCommand().setupFilter();
        Result result = manufacturerLogic.getManufacturers( command.getFilter(), backing.getPager());
        backing.getManufacturersCommand().setResult( result );
        // backing.createAllowedControllers( result );
        // DevicesBacking.getInstance( session ).createAllowedDevicesFromControllers( result );

        // prepare models
        backing.bindToModel( model );
        model.addAttribute( NAME_REPORT_DATA, command );
        model.addAttribute( OperatorUserPrincipal.SESSION_NAME, session.getAttribute(OperatorUserPrincipal.SESSION_NAME));

        return "management/controllers";
    }
    
//================================================================================

    @RequestMapping( value = "/management/addcontroller.do", method = RequestMethod.GET )
    public String openAddController(
            HttpSession session, Model model ) throws Exception {

        // validate operator's permissions
        Operator op = getOperator(session);
        if( op.getType() != OperatorType.ADMIN )
        {
            return "redirect:/management/controllers.do";
        }
            
        ManufacturerDetailCommand command = new ManufacturerDetailCommand();
        // command.setCompany( getOperator( session ).getCompany());
        
        model.addAttribute( NAME_DETAIL_DATA, command );
        // model.addAttribute( NAME_COMPANIES, manufacturerLogic.getCompanies());
        // model.addAttribute( NAME_CONTROLLER_GROUPS, controllerLogic.getControllerGroups( command.getCompany()));
        model.addAttribute( OperatorUserPrincipal.SESSION_NAME, session.getAttribute(OperatorUserPrincipal.SESSION_NAME));
        
        return "management/controllerdetail";
    }

//--------------------------------------------------------------------------------

    @RequestMapping( value = "/management/addcontroller.do", method = RequestMethod.POST )
    public String applyAddController(
            HttpSession session, Model model,
            @ModelAttribute( NAME_DETAIL_DATA ) ManufacturerDetailCommand controller, Errors errors ) throws Exception {

        // validate operator's permissions
        Operator op = getOperator(session);
        if( op.getType() != OperatorType.ADMIN )
        {
            return "redirect:/management/controllers.do";
        }
            
        new ManufacturerValidator().validate(controller, errors);
        if (errors.hasErrors()) {

            // model.addAttribute( NAME_COMPANIES, manufacturerLogic.getCompanies());
           // model.addAttribute( NAME_CONTROLLER_GROUPS, manufacturerLogic.getControllerGroups( getOperator( session ).getCompany()));

            return "management/controllerdetail";
        }

        manufacturerLogic.addManufacturer( controller.getController(), controller.getNewPassword());
        model.addAttribute( OperatorUserPrincipal.SESSION_NAME, session.getAttribute(OperatorUserPrincipal.SESSION_NAME));
        
        return "redirect:/management/controllers.do";
    }

//================================================================================

    @RequestMapping( value = "/management/editcontroller.do", method = RequestMethod.GET )
    public String openControllerDetail(
            HttpSession session, Model model,
            @RequestParam( value = "id", required = false ) String manufacturerId  ) throws Exception {
        
        if( manufacturerId == null ) {
            throw new Exception( "Unknown controller" );
        // } else if( ManufacturersBacking.getInstance( session ).allowedController( manufacturerId )) {
            // fall down
        // } else {
            // throw new Exception( "Unknown controller" );
        }

        ManufacturerDetailCommand controllerCommand =
                new ManufacturerDetailCommand( manufacturerLogic.getManufacturer( new Long( manufacturerId  )));
        // if( controllerCommand.getDevices() != null && controllerCommand.getDevices().size() > 0 ) {
        //     for( Device device : controllerCommand.getDevices()) {
        //         DevicesBacking.getInstance( session ).addAllowedDevice( device.getDeviceId().toString());
        //     }
        // }
        
        // model.addAttribute( NAME_COMPANIES, controllerLogic.getCompanies());
       //  model.addAttribute( NAME_CONTROLLER_GROUPS, controllerLogic.getControllerGroups( getOperator( session ).getCompany()));
        model.addAttribute( NAME_DETAIL_DATA, controllerCommand );
        model.addAttribute( OperatorUserPrincipal.SESSION_NAME, session.getAttribute(OperatorUserPrincipal.SESSION_NAME));
        
        return "management/controllerdetail";
    }

//--------------------------------------------------------------------------------

    @RequestMapping( value = "/management/editcontroller.do", method = RequestMethod.POST )
    public String applyControllerDetail(
            HttpSession session, Model model,
            @ModelAttribute( NAME_DETAIL_DATA ) ManufacturerDetailCommand controller, Errors errors ) throws Exception {
        
        // validate operator's permissions
        Operator op = getOperator(session);
        if( op.getType() != OperatorType.ADMIN )
        {
            return "redirect:/management/controllers.do";
        }
            
        new ManufacturerValidator().validate(controller, errors);
        if (errors.hasErrors()) {

            // model.addAttribute( NAME_COMPANIES, controllerLogic.getCompanies());
            // model.addAttribute( NAME_CONTROLLER_GROUPS, controllerLogic.getControllerGroups( getOperator( session ).getCompany()));
            model.addAttribute( NAME_DETAIL_DATA, controller );
            model.addAttribute( OperatorUserPrincipal.SESSION_NAME, session.getAttribute(OperatorUserPrincipal.SESSION_NAME));

            return "management/controllerdetail";
        } 

        manufacturerLogic.updateManufacturer( controller.getController(), controller.getNewPassword());
        
        return "redirect:/management/controllers.do";
    }
    
//--------------------------------------------------------------------------------

    private Operator getOperator( HttpSession session ) {
        return ((OperatorUserPrincipal)session.getAttribute( OperatorUserPrincipal.SESSION_NAME )).getOperator();
    }
    
//================================================================================

}
