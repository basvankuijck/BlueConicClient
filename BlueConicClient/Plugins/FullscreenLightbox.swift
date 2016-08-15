/*
* $LastChangedBy$
* $LastChangedDate$
* $LastChangedRevision$
* $HeadURL$
*
* Copyright 2014 BlueConic Inc./BlueConic B.V. All rights reserved.
*/

import Foundation
import UIKit

public class FullscreenLightbox: Plugin {
    private var _client: BlueConicClient?
    private var _context: InteractionContext?
    private var _lightbox: BCLightbox!

    public override convenience init(client: BlueConicClient, context: InteractionContext) {
        self.init()
        self._client = client
        self._context = context
    }

    public override func onLoad() {
        if self._client?.getViewController() == nil {
            return
        }
		//println("[FullscreenLightbox] Lightbox.onload")



        let topController = selectTopViewController()
        let iconUrl = getValueFromParameters("iconUrl")

        if let url = getValueFromParameters("url") {
            self._lightbox = BCLightbox.makeURLString(topController, urlString: url, iconUrl: iconUrl)

        } else if let html = getValueFromParameters("html") {
            self._lightbox = BCLightbox.makeContentFromHtml(topController, html: html, iconUrl: iconUrl)
        } else {
            let content = getValueFromParameters("content")
            let cssUrl = getValueFromParameters("cssUrl")
            let inlineCss = getValueFromParameters("inlineCss")
            let htmlString = BCLightbox.constructHtml(topController, content: content, cssUrl: cssUrl, inlineCss: inlineCss)
            self._lightbox = BCLightbox.makeContent(topController, content: htmlString, baseURL: nil, iconUrl: iconUrl)

        }
        if let margins = getValueFromParameters("margins") {
            self._lightbox.margin = (margins as NSString).floatValue
        }

        if let hideTimer = getValueFromParameters("hideTimer") {
            self._lightbox.hideTimer = Int(hideTimer)
        }

        // If we are loading an url, it will automatically show when the page has finished loading, in all other cases, show when it's done here

        self._lightbox.showIfReady()

    }

    private func selectTopViewController() -> UIViewController {
        var topMostViewController = self._client?.getViewController()
        while topMostViewController!.parentViewController != nil {
            topMostViewController = topMostViewController!.parentViewController
        }
        return topMostViewController!
    }

    private func getValueFromParameters(key: String) -> String? {
        let parameters: Dictionary<String, [String]> = self._context!.getParameters()

        if let values = parameters[key] where values.count > 0 {
            if values[0] != "" {
                return values[0]
            }
        }
        return nil
    }
}

// -- BlueConic Lightbox -- Implementation
// -- Represents a pop-up view above the other views --

public class BCLightbox: NSObject, UIWebViewDelegate {

    // private properties
    private var _viewController: UIViewController!
    private var _backgroundView: UIView = UIView()
    private var _lightboxView: UIWebView = UIWebView()
    private var _closeButton: UIButton = UIButton()
    private var _iconUrl: String?
    private var isLoaded: Bool = false
    private var isReadyForShowing: Bool = false
    private var isShown: Bool = false
    var token: dispatch_once_t = 0
    public var margin: Float = 0
    public var hideTimer: Int?
    private let lightBoxBackgroundColor: UIColor = UIColor(white: 0, alpha: 0.5)


    public var lightboxView: UIWebView {
        get {
            return self._lightboxView
        }
        set {
            self._lightboxView = newValue
        }
    }

    public func webView(webView: UIWebView, shouldStartLoadWithRequest request: NSURLRequest, navigationType: UIWebViewNavigationType) -> Bool {
        if navigationType == UIWebViewNavigationType.LinkClicked {
            UIApplication.sharedApplication().openURL(request.URL!)
            return false
        }
        return true
    }

    init(viewController: UIViewController, iconUrl: String?) {
        super.init()
        self._viewController = viewController
        self._iconUrl = iconUrl
    }

    deinit {
        self._lightboxView.removeFromSuperview()
        self._backgroundView.removeFromSuperview()
    }

    public class func constructHtml(viewController: UIViewController, content: String?, cssUrl: String?, inlineCss: String?) -> String {
        var html = ""
        if let content = content {

            let htmlTop = "<!DOCTYPE html><html><head>"
            let htmlMiddle = "</head><body>\n<div class=\"bcFullScreenLightboxWrapper\">\n\t<div class=\"bcFullScreenLightboxMain\">"
            let htmlBottom = "\n</div></div></body></html>"
            let style = self.setHtmlStyle(viewController, content: content, inlineCss: inlineCss)

            html = htmlTop
            html += style
            if let cssUrl = cssUrl {
                html += "<link rel=\"stylesheet\" type=\"text/css\" href=\"\(cssUrl)\" />"
            }

            html += htmlMiddle

            html += extractContentFromHtml(content)

            html += htmlBottom
        }
		// println(html)
        return html
    }

    private class func extractContentFromHtml(content: String) -> String {
        var result = content
        if let firstBodyTagRange = content.rangeOfString("<body>") {
            result = content.substringFromIndex(firstBodyTagRange.endIndex)
        }
        if let secondBodyTagRange = content.rangeOfString("</body>") {
            result = content.substringToIndex(secondBodyTagRange.startIndex)
        }
        return result
    }


    /**
    add default styling for:
     - no margins
     If the content only contains an image:
     - center alignment
     - scale image according to the width or height
    */
    private class func setHtmlStyle(viewController: UIViewController, content: String, inlineCss: String?) -> String {
        var style = "<style type=\"text/css\">\n"

        // detect if the content only contains an image
        if content.rangeOfString("<img ") != nil && content.rangeOfString("<p>") == nil {

			style += "img {max-height: 100%;" +
				"max-width:100%;" +
				"width:100%;" +
				"height:100%;" +
				"object-fit:contain;}\n"
			style += ".bcFullScreenLightboxMain {" +
						"display: -webkit-flex;" +
						"-webkit-align-items: center;" +
						"-webkit-justify-content: center;" +
						"-webkit-flex-direction:column;" +
						"height:100%}\n"
			style += ".bcFullScreenLightboxWrapper { height:100%;}"
			style += "body { height:100vh;}"
        } else {
            style += ".bcFullScreenLightboxMain {padding: 5px;}\n"
        }
        style += "* { margin: 0; padding: 0; }\n"
        style += "</style>"
        if let inlineCss = inlineCss {
            style += "<style type=\"text/css\">\(inlineCss)</style>"
        }
        return style
    }

    public class func makeContentFromHtml(viewController: UIViewController, html: String, iconUrl: String?) -> BCLightbox {
        return makeContent(viewController, content: html, baseURL: nil, iconUrl: iconUrl)
    }

    public class func makeContent(viewController: UIViewController, content: String, baseURL: NSURL!, iconUrl: String?) -> BCLightbox {
        let lightbox = BCLightbox(viewController: viewController, iconUrl: iconUrl)
        lightbox.create()


        lightbox.lightboxView.loadHTMLString(content, baseURL: baseURL)
        return lightbox
    }

    public class func makeURLString(viewController: UIViewController, urlString: String, iconUrl: String?) -> BCLightbox {
        return BCLightbox.makeURL(viewController, url: NSURL(string: urlString)!, iconUrl: iconUrl)
    }

    public class func makeURL(viewController: UIViewController, url: NSURL, iconUrl: String?) -> BCLightbox {
        var newUrl = url
        if url.scheme == "" {
            if newUrl.host != nil {
                newUrl = NSURL(scheme: "http", host: url.host, path: url.path!)!
            } else {
                newUrl = NSURL(string: "http://\(url.path!)")!
            }
        }
        return BCLightbox.makeURLRequest(viewController, request: NSURLRequest(URL: newUrl), iconUrl: iconUrl)
    }


    public class func makeURLRequest(viewController: UIViewController, request: NSURLRequest, iconUrl: String?) -> BCLightbox {
        let lightbox = BCLightbox(viewController: viewController, iconUrl: iconUrl)
        lightbox.create()
        lightbox.lightboxView.delegate = lightbox
        lightbox.lightboxView.loadRequest(request)
        return lightbox
    }


    public func webViewDidFinishLoad(webView: UIWebView) {
        if !self.isLoaded {
            self.isLoaded = true
            if (self.isReadyForShowing) {
                self.show()
            }
        }
    }

    public func showIfReady() {
        self.isReadyForShowing = true
        if self.isLoaded {
            self.show()
        }
    }

    public func show() {
        dispatch_once(&token) {
            if let view = self._viewController?.view {
                let verticalMargin = CGRectGetHeight(view.bounds) * (CGFloat(self.margin) / 100)
                let horizontalMargin = CGRectGetWidth(view.bounds) * (CGFloat(self.margin) / 100)
                let topGuide = self._viewController!.topLayoutGuide

                // Settings for Background View
                view.addSubview(self._backgroundView)
                // constraints
                let backgroundDictionary = ["background": self._backgroundView]

                //position constraints
                let horizontalBackgroundConstraint: NSArray = NSLayoutConstraint.constraintsWithVisualFormat("H:|-0-[background]-0-|", options: NSLayoutFormatOptions(rawValue: 0), metrics: nil, views: backgroundDictionary)

                let verticalBackgroundConstraint: NSArray = NSLayoutConstraint.constraintsWithVisualFormat("V:|-0-[background]-0-|", options: NSLayoutFormatOptions.AlignAllLeading, metrics: nil, views: backgroundDictionary)

                self._viewController!.view.addConstraints(horizontalBackgroundConstraint as! [NSLayoutConstraint])
                self._viewController!.view.addConstraints(verticalBackgroundConstraint as! [NSLayoutConstraint])


                // Settings for Lightbox View
                view.addSubview(self._lightboxView)
                self._lightboxView.addSubview(self._closeButton)


                // constraints
                let lightboxDictionary = ["lightbox": self._lightboxView, "topGuide": topGuide, "closeButton": self._closeButton]

                //position constraints

                let horizontalConstraint: NSArray = NSLayoutConstraint.constraintsWithVisualFormat("H:|-\(horizontalMargin)-[lightbox]-\(horizontalMargin)-|", options: NSLayoutFormatOptions(rawValue: 0), metrics: nil, views: lightboxDictionary as! [String : AnyObject])


                let verticalConstraint: NSArray = NSLayoutConstraint.constraintsWithVisualFormat("V:|[topGuide]-\(verticalMargin)-[lightbox]-\(verticalMargin)-|", options: NSLayoutFormatOptions.AlignAllLeading, metrics: nil, views: lightboxDictionary as! [String : AnyObject])


                let horizontalCloseButtonConstraint: NSArray = NSLayoutConstraint.constraintsWithVisualFormat("H:[closeButton]-10-|", options: NSLayoutFormatOptions(rawValue: 0), metrics: nil, views: lightboxDictionary as! [String : AnyObject])

                let verticalCloseButtonConstraint: NSArray = NSLayoutConstraint.constraintsWithVisualFormat("V:|-10-[closeButton]", options: NSLayoutFormatOptions(rawValue: 0), metrics: nil, views: lightboxDictionary as! [String : AnyObject])

                self._viewController!.view.addConstraints(horizontalConstraint as! [NSLayoutConstraint])
                self._viewController!.view.addConstraints(verticalConstraint as! [NSLayoutConstraint])

                self._viewController!.view.addConstraints(horizontalCloseButtonConstraint as! [NSLayoutConstraint])
                self._viewController!.view.addConstraints(verticalCloseButtonConstraint as! [NSLayoutConstraint])

                if let hideTimer = self.hideTimer {
                   NSTimer.scheduledTimerWithTimeInterval(NSTimeInterval(hideTimer), target: self, selector: #selector(BCLightbox.hide), userInfo: nil, repeats: false)
                }
            }
        }
    }

    public func hide() {
        if self._viewController?.view != nil {

            self._backgroundView.removeFromSuperview()

            self._lightboxView.removeFromSuperview()
            self._closeButton.removeFromSuperview()
        }
    }

    private func create() {

        self._backgroundView = UIView()
        self._lightboxView = UIWebView()
        self._closeButton = UIButton(type: .Custom)

        let fmBundle = NSBundle(forClass: BCLightbox.self)
        // if an icon has been specified use that, otherwise use the supplied closing icon
        if let iconUrlString = self._iconUrl {
            if let iconUrl = NSURL(string: iconUrlString) {
                if let iconUrlData = NSData(contentsOfURL: iconUrl) {
                    if let image = UIImage(data: iconUrlData) {
                        self._closeButton.setImage(image, forState: .Normal)
                        self._closeButton.addTarget(self, action: #selector(BCLightbox.hide), forControlEvents: UIControlEvents.AllTouchEvents)
                    }
                }
            }
        } else if let imagePath = fmBundle.pathForResource("close", ofType: "png") {
            if let image = UIImage(contentsOfFile: imagePath) {
                self._closeButton.setImage(image, forState: .Normal)
                self._closeButton.addTarget(self, action: #selector(BCLightbox.hide), forControlEvents: UIControlEvents.AllTouchEvents)
            }
        }

        if self._viewController != nil {
            let singleFingerTap = UITapGestureRecognizer(target: self, action: #selector(BCLightbox.handleLightBox(_:)))
            self._backgroundView.addGestureRecognizer(singleFingerTap)

            self._lightboxView.translatesAutoresizingMaskIntoConstraints = false
            self._backgroundView.translatesAutoresizingMaskIntoConstraints = false
            self._closeButton.translatesAutoresizingMaskIntoConstraints = false

            _backgroundView.backgroundColor = self.lightBoxBackgroundColor
        }
        self.lightboxView.delegate = self
    }

    func handleLightBox(recognizer: UIGestureRecognizer) {
        hide()
    }


}
