package cz.smartcontrol.licensing.web.interceptors;

import cz.smartcontrol.licensing.web.controllers.management.OperatorSecuredArea;
import cz.smartcontrol.licensing.web.controllers.management.OperatorUserPrincipal;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import org.springframework.web.servlet.handler.HandlerInterceptorAdapter;

/**
 *
 * @author strzinek
 */
public class OperatorWebInterceptor extends HandlerInterceptorAdapter {

    @Override
    public boolean preHandle(HttpServletRequest request, HttpServletResponse response,
            Object handler) throws Exception {

        if (handler != null && handler instanceof OperatorSecuredArea)
        {
            OperatorUserPrincipal p = null;

            if( request.getSession() != null )
            {
                p = (OperatorUserPrincipal) request.getSession().getAttribute(OperatorUserPrincipal.SESSION_NAME);
            }

            if( p == null || !p.isUserLoggedIn())
            {
                response.sendRedirect(request.getContextPath() + "/management/login.do");
                return false;
            }
        }

        return true;
    }
}
