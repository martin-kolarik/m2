package cz.smartcontrol.licensing.web.interceptors;

import cz.smartcontrol.licensing.web.controllers.PublicSecuredArea;
import cz.smartcontrol.licensing.web.controllers.PublicUserPrincipal;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import org.springframework.web.servlet.handler.HandlerInterceptorAdapter;

/**
 *
 * @author strzinek
 */
public class PublicWebInterceptor extends HandlerInterceptorAdapter {

    @Override
    public boolean preHandle(HttpServletRequest request, HttpServletResponse response,
            Object handler) throws Exception {

        if (handler != null && handler instanceof PublicSecuredArea)
        {
            PublicUserPrincipal p = null;

            if (request.getSession() != null)
            {
                p = (PublicUserPrincipal) request.getSession().getAttribute( PublicUserPrincipal.SESSION_NAME );
            }

            if( p == null || !p.isUserLoggedIn())
            {
                response.sendRedirect(request.getContextPath() + "/login.do");
                return false;
            }
        }

        return true;
    }
}
