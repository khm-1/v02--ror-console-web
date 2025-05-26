class PageController < ApplicationController
    def home 
        @title = "Home"
        @description = "Welcome to the home page of our application."

        # app/views/page/home.html.erb
        
    end

    def about
        @title = "About Us"
        @description = "Learn more about our application and what we do."

        # app/views/page/about.html.erb
    end
end
