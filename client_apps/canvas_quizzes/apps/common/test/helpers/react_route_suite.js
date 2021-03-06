/*
 * Copyright (C) 2015 - present Instructure, Inc.
 *
 * This file is part of Canvas.
 *
 * Canvas is free software: you can redistribute it and/or modify it under
 * the terms of the GNU Affero General Public License as published by the Free
 * Software Foundation, version 3 of the License.
 *
 * Canvas is distributed in the hope that it will be useful, but WITHOUT ANY
 * WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
 * A PARTICULAR PURPOSE. See the GNU Affero General Public License for more
 * details.
 *
 * You should have received a copy of the GNU Affero General Public License along
 * with this program. If not, see <http://www.gnu.org/licenses/>.
 */

require([ 'old_version_of_react_used_by_canvas_quizzes_client_apps' ], function(React) {
  window.React = React;

// Creates a DOM element that ReactSuite tests will use tmount the subject
// in. Although jasmine_react does that automatically on the start of each
// ReactSuite, we will prepare it before-hand and expose it to jasmine.fixture
// if you need to access directly.
require([ 'jasmine_react', 'old_version_of_react-router_used_by_canvas_quizzes_client_apps'], function(ReactSuite, ReactRouter) {
  var Route = ReactRouter.Route;

  console.log("")

  var exports = function(suite, type, initialProps) {
    var routes = [
        Route({ name: "app", path: "/", handler: type })
    ];

    var Sink = React.createClass({
      render: function() { return React.DOM.div({}); }
    });

    suite.beforeEach(function() {
      var routeMap = ReactRouter.Routes({
        location: "hash",
        children: routes
      });

      var subject = window.subject = React.renderComponent(routeMap, document.createElement("div"));
    });


    suite.afterEach(function() {
      window.subject = null;
      routeMap = null;
    });

    this.stubRoutes = function(specs) {
      routes = routes.concat(specs.map(function(spec) {
        if (!spec.handler) {
          spec.handler = Sink;
        }

        return Route(spec);
      }));
    };

    return this;
  };

  window.reactRouterSuite = exports;
});

});