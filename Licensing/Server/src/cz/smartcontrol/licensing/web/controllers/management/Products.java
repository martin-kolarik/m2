package cz.smartcontrol.licensing.web.controllers.management;

import cz.smartcontrol.licensing.business.facade.ManufacturerFacade;
import cz.smartcontrol.licensing.business.facade.ProductFacade;
import cz.smartcontrol.query.Result;
import cz.smartcontrol.licensing.domain.Operator;
import cz.smartcontrol.licensing.domain.OperatorType;
import cz.smartcontrol.licensing.web.commands.ProductsCommand;
import cz.smartcontrol.licensing.web.session.ProductsBacking;
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
@SessionAttributes( {Products.NAME_REPORT_DATA, Products.NAME_DETAIL_DATA}        )
public class Products implements OperatorSecuredArea {
    
    public static final String NAME_REPORT_DATA = "devicesData";
    public static final String NAME_DETAIL_DATA = "device";
    public static final String NAME_COMPANIES = "companies";
    
    @Autowired
    ProductFacade productLogic;
    
    @Autowired
    ManufacturerFacade manufacturerLogic;
    
//================================================================================

    @RequestMapping( value = "/management/products.do", method = RequestMethod.GET )
    public String setupReport(
            HttpSession session, Model model,
            @RequestParam( value = "items", required = false ) String pageSizeIncrement,
            @RequestParam( value = "page", required = false ) String page,
            @RequestParam( value = "order", required = false ) String orderBy ) throws Exception {

        // prepare backing
        ProductsBacking backing = ProductsBacking.getInstance( session );
        
        // apply paging and ordering
        backing.getPager().updateByWebRequest( pageSizeIncrement, page, orderBy );

        // do action
        ProductsCommand command = backing.getProductsCommand();

        command.setupFilter();
        Result result = productLogic.getProducts( command.getFilter(), backing.getPager());
        command.setResult( result );
        // backing.createAllowedDevices( result );
        // ControllersBacking.getInstance( session ).createAllowedControllersFromDevices( result );

        // prepare models
        backing.bindToModel( model );
        model.addAttribute( NAME_REPORT_DATA, command );
        model.addAttribute( OperatorUserPrincipal.SESSION_NAME, session.getAttribute(OperatorUserPrincipal.SESSION_NAME));

        return "management/devices";
    }
    
//--------------------------------------------------------------------------------

    @RequestMapping( value = "/management/products.do", method = RequestMethod.POST )
    public String processReport(
            HttpSession session, Model model,
            @ModelAttribute( NAME_REPORT_DATA ) ProductsCommand command ) throws Exception {

        // no validation needed now
        ProductsBacking backing = ProductsBacking.getInstance( session );
        backing.getPager().setDisplayPage( 1 ); // reset paging when changing filter (POST request)
        backing.getProductsCommand().setupFilter();
        Result result = productLogic.getProducts( command.getFilter(), backing.getPager());
        backing.getProductsCommand().setResult( result );
        // backing.createAllowedDevices( result );
        // ControllersBacking.getInstance( session ).createAllowedControllersFromDevices( result );

        // prepare models
        backing.bindToModel( model );
        model.addAttribute( NAME_REPORT_DATA, command );
        model.addAttribute( OperatorUserPrincipal.SESSION_NAME, session.getAttribute(OperatorUserPrincipal.SESSION_NAME));

        return "management/devices";
    }
    
//================================================================================

    @RequestMapping( value = "/management/products.do", method = RequestMethod.GET )
    public String openAddDevice(
            HttpSession session, Model model ) throws Exception {
        
        // validate operator's permissions
        Operator op=getOperator(session);
        if( op.getType() != OperatorType.MANUFACTURER ) {
            return "redirect:/management/products.do";
        }
            
        // DeviceDetailCommand command = new DeviceDetailCommand();
        
        // model.addAttribute( NAME_DETAIL_DATA, command );
        // model.addAttribute( NAME_COMPANIES, manufacturerLogic.getCompanies());
        // model.addAttribute( OperatorUserPrincipal.SESSION_NAME, session.getAttribute(OperatorUserPrincipal.SESSION_NAME));
        
        return "management/devicedetail";
    }

//--------------------------------------------------------------------------------

/*
    @RequestMapping( value = "/management/adddevice.do", method = RequestMethod.POST )
    public String applyAddDevice(
            HttpSession session, Model model,
            @ModelAttribute( NAME_DETAIL_DATA ) DeviceDetailCommand command, Errors errors ) throws Exception {

        // validate operator's permissions
        Operator op=getOperator(session);
        if( op.getType()!=OperatorType.OPERATOR ) {
            return "redirect:/management/devices.do";
        }
            
        new ManufacturerValidator().validate(command, errors);
        if (errors.hasErrors()) {
            
            model.addAttribute( NAME_DETAIL_DATA, command );
            model.addAttribute( NAME_COMPANIES, manufacturerLogic.getCompanies());
            model.addAttribute( OperatorUserPrincipal.SESSION_NAME, session.getAttribute(OperatorUserPrincipal.SESSION_NAME));

            return "management/devicedetail";
        }

        productLogic.addDevice( command.getDevice());
        
        return "redirect:/management/devices.do";
    }

//================================================================================

    @RequestMapping( value = "/management/editdevice.do", method = RequestMethod.GET )
    public String openControllerDetail(
            HttpSession session, Model model,
            @RequestParam( value = "id", required = false ) String deviceId ) throws Exception {
        
        if( deviceId == null ) {
            throw new Exception( "Unknown device" );
        // } else if( ProductsBacking.getInstance( session ).allowedDevice( deviceId )) {
        //     // fall down
        // } else {
        //     throw new Exception( "Unknown device" );
        }

        DeviceDetailCommand device =
                new DeviceDetailCommand( productLogic.getDevice( new Long( deviceId )));
        if( device.getController() != null ) {
            ControllersBacking.getInstance( session ).addAllowedController( device.getController().getControllerId().toString());
        }
        
        model.addAttribute( NAME_COMPANIES, manufacturerLogic.getCompanies());
        model.addAttribute( NAME_DETAIL_DATA, device );
        model.addAttribute( OperatorUserPrincipal.SESSION_NAME, session.getAttribute(OperatorUserPrincipal.SESSION_NAME));
        
        return "management/devicedetail";
    }

//--------------------------------------------------------------------------------

    @RequestMapping( value = "/management/editdevice.do", method = RequestMethod.POST )
    public String applyControllerDetail(
            HttpSession session, Model model,
            @ModelAttribute( NAME_DETAIL_DATA ) DeviceDetailCommand device, Errors errors ) throws Exception {
        
        // validate operator's permissions
        Operator op=getOperator(session);
        if( op.getType()!=OperatorType.OPERATOR ) {
            return "redirect:/management/devices.do";
        }
            
        new ManufacturerValidator().validate(device, errors);
        if (errors.hasErrors()) {

            model.addAttribute( NAME_COMPANIES, manufacturerLogic.getCompanies());
            model.addAttribute( NAME_DETAIL_DATA, device );
            model.addAttribute( OperatorUserPrincipal.SESSION_NAME, session.getAttribute(OperatorUserPrincipal.SESSION_NAME));

            return "management/devicedetail";
        } 

        // update itself
        productLogic.updateDevice( device.getDevice());

        // embedded part of unlinkController method
        if( device.getUnlinkController() != null && device.getUnlinkController()) {
            productLogic.unlinkController( device.getDevice(), device.getController().getControllerId());
        }
        
        return "redirect:/management/devices.do";
    }
    
*/ 

//--------------------------------------------------------------------------------

    private Operator getOperator( HttpSession session ) {
        return ((OperatorUserPrincipal)session.getAttribute( OperatorUserPrincipal.SESSION_NAME )).getOperator();
    }
    
//================================================================================

}
